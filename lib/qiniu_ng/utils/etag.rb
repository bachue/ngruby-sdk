# frozen_string_literal: true

require 'digest'

module QiniuNg
  module Utils
    # 七牛 Etag 计算实用工具
    #
    # @see https://developer.qiniu.com/kodo/manual/1231/appendix#3
    class Etag
      # 七牛 Etag 流计算器
      #
      # @example
      #   actual_etag = String.new
      #   reader = QiniuNg::Etag::Reader.new(reader, etag)
      #   reader.read
      #   expect(expected_etag).to eq actual_etag
      class Reader
        # 初始化流计算器
        #
        # @example
        #   reader = QiniuNg::Etag::Reader.new(reader, etag)
        #
        # @param [#read] io 数据流来源
        # @param [String] etag 存放计算得到的 Etag 结果，注意，该字符串必须不能被冻结
        def initialize(io, etag)
          @io = io
          @etag = etag
          @have_read = 0
          @buffer = String.new
          @sha1s = []
          %i[path eof? close closed?].select { |method| io.respond_to?(method) }
                                     .each { |method| define_singleton_method(method) { io.public_send(method) } }
          if io.respond_to?(:each_chunk)
            define_singleton_method(:each_chunk) do |&block|
              @io.each_chunk do |chunk|
                update_buffer_and_calculate_etag(chunk)
                block.call(chunk)
              end
            end
          end

          return unless io.respond_to?(:readpartial)

          define_singleton_method(:readpartial) do |length, outbuf|
            outbuf = outbuf ? outbuf.replace('') : String.new
            @io.readpartial(length, outbuf)
            update_buffer_and_calculate_etag(outbuf)
            outbuf
          end
        end

        # 调用给定的 io 的 #read 方法，同时计算 Etag
        #
        # @param [Integer] length 读取的数据尺寸上限，单位为字节。如果传入 nil，将读取所有数据直到 io.eof? 为 true。如果传入 0，将总是返回一个空字符串
        # @param [String] outbuf 用于接受读到的数据
        # @return [String, nil] 返回读取到的数据
        def read(length = nil, outbuf = nil)
          outbuf = outbuf ? outbuf.replace('') : String.new
          if length.nil?
            @io.read(nil, outbuf)
            @etag.replace(Etag.from_data(outbuf))
          elsif length.positive?
            @io.read(length, outbuf)
            update_buffer_and_calculate_etag(outbuf)
          end
          outbuf
        end

        # @!visibility private
        def replace_by_io(io)
          @io = io
        end

        private

        def update_buffer_and_calculate_etag(chunk)
          @buffer << chunk
          while @buffer.size >= QiniuNg::BLOCK_SIZE
            @sha1s << sha1(@buffer[0...QiniuNg::BLOCK_SIZE])
            @buffer.replace(@buffer[QiniuNg::BLOCK_SIZE..-1])
          end
          return unless @io.eof?

          @sha1s << sha1(@buffer) unless @buffer.empty?
          @buffer = String.new
          @etag.replace(Etag.encode_sha1s(@sha1s))
        end

        def sha1(data)
          Etag.sha1(data)
        end
      end

      class << self
        # 根据指定的字符串计算 Etag
        #
        # @param [String] data 用于计算 Etag 的字符串
        # @return [String] 返回的 Etag
        def from_data(data)
          from_io StringIO.new(data)
        end
        alias from_str from_data

        # 对指定的文件路径计算 Etag
        #
        # @param [Pathname] path 用于计算 Etag 的文件路径
        # @return [String] 返回的 Etag
        def from_file_path(path)
          File.open(path, 'rb') { |io| from_file(io) }
        end

        # 对指定的数据流中的数据计算 Etag
        #
        # 注意，该方法会调用 io#read 来消费数据流中的数据，直到消费完毕为止
        #
        # 用户可能需要在该方法被调用后关闭 io，否则可能引发内存泄漏
        #
        # @example
        #   etag = begin
        #            QiniuNg::Etag.from_io(stream)
        #          ensure
        #            stream.close
        #          end
        #
        # @param [#read] io 用于计算 Etag 的数据流
        # @return [String] 返回的 Etag
        def from_io(io)
          io.binmode

          sha1s = []
          until io.eof?
            block_data = io.read(QiniuNg::BLOCK_SIZE)
            sha1s << sha1(block_data)
          end
          encode_sha1s(sha1s)
        end
        alias from_file from_io

        # @!visibility private
        def encode_sha1s(sha1s)
          case sha1s.size
          when 0
            'Fto5o-5ea0sNMlW_75VgGJCv2AcJ'
          when 1
            Base64.urlsafe_encode64(0x16.chr + sha1s.first)
          else
            Base64.urlsafe_encode64(0x96.chr + sha1(sha1s.join))
          end
        end

        # @!visibility private
        def sha1(data)
          Digest::SHA1.digest(data)
        end
      end
    end
  end
end
