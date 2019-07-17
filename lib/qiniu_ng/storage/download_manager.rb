# frozen_string_literal: true

require 'down'
require 'forwardable'

module QiniuNg
  module Storage
    class DownloadManager
      # 校验和出错
      class ChecksumError < Faraday::Error
      end

      # 下载重试时监测到数据 Etag 发生变化
      class EtagChanged < Faraday::Error
      end

      # 对七牛存储的文件提供流式读取器
      class Reader
        extend Forwardable
        # @!visibility private
        RETRYABLE_EXCEPTIONS = [Down::ResponseError, Down::ConnectionError, Down::TimeoutError, Down::SSLError].freeze

        # 构造方法
        #
        # @param [String] url 文件的下载地址
        # @param [Range] range 文件读取范围
        # @param [Boolean] disable_checksum 禁用校验和（不推荐禁用）
        # @param [Integer, nil] max_retry 最大重试次数，如果设置为 nil，将无限重试
        # @param [Lambda] backup_url_proc 提供一个闭包，用于返回备用 URL，如果不提供，或该闭包返回 nil，则不会继续重试，直接抛出异常。
        #   当 max_retry 为 nil 时，该参数不会起作用
        # @param [Hash] options 额外的 Down 参数
        def initialize(url, range: nil, disable_checksum: false, max_retry: 5, backup_url_proc: nil, **options)
          @url = url
          @range = range
          @max_retry = max_retry
          @options = options
          @backup_url_proc = backup_url_proc
          @headers = { 'User-Agent' => "QiniuRubyNg::Down/v#{VERSION}/#{RUBY_DESCRIPTION}" }
          if @range
            @headers['Range'] = "bytes=#{@range.begin}-#{@range.max if @range&.end&.> 0}"
            disable_checksum = true
          end
          @have_read = 0
          @retried = 0
          @io = begin
                  Down.open(@url, headers: @headers, **options)
                rescue *RETRYABLE_EXCEPTIONS => _e
                  @retried += 1
                  if @max_retry && @retried > @max_retry
                    raise if @backup_url_proc.nil?

                    backup_url = @backup_url_proc.call
                    raise if backup_url.nil?

                    @url = backup_url
                    @retried = 0
                  end
                  retry
                end
          @io.instance_variable_set(:@closed, nil)
          @expected_etag = nil
          @actual_etag = nil
          return if disable_checksum

          @expected_etag = extract_etag(@io)
          return unless @expected_etag

          @actual_etag = String.new
          @io = Utils::Etag::Reader.new(@io, @actual_etag)
        end
        def_delegators :@io, :pos, :size, :eof?, :close, :closed?, :encoding, :encoding=

        # 读取指定长度的数据
        #
        # 该函数将尽力读取到指定长度的数据，直到数据被读完为止，可能会在读取期间发生多次阻塞。
        #
        # @param [Integer, nil] length 需要读取的数据长度，如果为 nil，则读取整个文件
        # @param [String, nil] outbuf 将读取的数据填入指定字符串缓存中，注意，该字符串必须不能被冻结
        # @raise [QiniuNg::Storage::DownloadManager::ChecksumError] 校验和出错
        # @raise [QiniuNg::Storage::DownloadManager::EtagChanged] 下载重试时监测到数据 Etag 发生变化
        # @return [String, nil] 返回被读取的数据，如果返回空字符串或 nil，则数据已经被读取完毕
        def read(length = nil, outbuf = nil)
          outbuf = outbuf ? outbuf.replace('') : String.new
          ret = with_autoretry { @io.read(length, outbuf).tap { |chunk| @have_read += chunk.bytesize } }
          validate_etag!
          ret
        end

        # 读取指定长度的分片数据
        #
        # 该函数将读取缓存中的数据，或是读取最多一个 TCP 包的数据并返回不超过指定长度的数据。
        #
        # 与 #read 不同，#readpartial 仅在缓存中没有数据时才发生至多一次阻塞，因此拥有更好的性能。
        # 但同时，该函数返回的数据量几乎总是小于指定长度。
        # 此外，如果数据被读取完毕，将会抛出 EOFError 异常。
        #
        # @param [Integer, nil] length 需要读取的数据长度，如果为 nil，则读取整个文件
        # @param [String, nil] outbuf 将读取的数据填入指定字符串缓存中，注意，该字符串必须不能被冻结
        # @raise [EOFError] 数据被读取完毕
        # @raise [QiniuNg::Storage::DownloadManager::ChecksumError] 校验和出错
        # @raise [QiniuNg::Storage::DownloadManager::EtagChanged] 下载重试时监测到数据 Etag 发生变化
        # @return [String, nil] 返回被读取的数据，如果返回空字符串或 nil，则数据已经被读取完毕
        def readpartial(length, outbuf = nil)
          outbuf = outbuf ? outbuf.replace('') : String.new
          ret = with_autoretry { @io.readpartial(length, outbuf).tap { |chunk| @have_read += chunk.bytesize } }
          validate_etag!
          ret
        end

        # 对于每一个分片进行遍历
        #
        # @param [Lambda] progress 接受一个进度回调闭包，
        #   该闭包接受两个参数，第一个参数为已经获取的文件内容大小，单位为字节，第二个参数为文件总大小，单位为字节
        # @yield [chunk] 对分片进行遍历处理
        # @raise [QiniuNg::Storage::DownloadManager::ChecksumError] 校验和出错
        # @raise [QiniuNg::Storage::DownloadManager::EtagChanged] 下载重试时监测到数据 Etag 发生变化
        # @yieldparam [String] chunk 分片内容
        def each_chunk(progress: nil, &block)
          raise ArgumentError, 'block is required' if block.nil?

          with_autoretry do
            @io.each_chunk do |chunk|
              block.call(chunk)
              @have_read += chunk.bytesize
              progress&.call(have_read, @io.size)
            end
          end
          validate_etag!
          nil
        end

        private

        def with_autoretry
          yield
        rescue *RETRYABLE_EXCEPTIONS => _e
          @retried += 1
          if @max_retry && @retried > @max_retry
            raise if @backup_url_proc.nil?

            backup_url = @backup_url_proc.call
            raise if backup_url.nil?

            @url = backup_url
            @retried = 0
          end

          if @have_read.positive?
            @range = if @range&.end&.> 0
                       (@have_read..@range.max)
                     else
                       (@have_read..-1)
                     end
          end
          reopen(range: @range)
          retry
        end

        def reopen(range: nil)
          begin
            @io.close if @io.respond_to?(:close)
          rescue StandardError
            # do nothing
          end

          @headers['Range'] = "bytes=#{range.begin}-#{range.max if range.end}" if range
          new_io = Down.open(@url, headers: @headers, **@options)
          new_io.instance_variable_set(:@closed, nil)
          if @expected_etag
            new_expected_etag = extract_etag(new_io)
            raise EtagChanged unless new_expected_etag == @expected_etag

            @io.replace_by_io(new_io)
          else
            @io = new_io
          end
        end

        def validate_etag!
          return unless @expected_etag && @actual_etag && !@actual_etag.empty?

          raise ChecksumError if @expected_etag != @actual_etag
        end

        def extract_etag(io)
          # 确定确实是七牛的资源，否则无法使用 Etag
          io.data.dig(:headers, 'Etag')&.sub(/^"([^"]+)"$/, '\1') if io.data.dig(:headers, 'X-Reqid')
        end
      end
    end
  end
end
