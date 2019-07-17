# frozen_string_literal: true

require 'pathname'
require 'forwardable'

module QiniuNg
  module Storage
    # @abstract 七牛文件的下载地址
    class URL < String
      # @!visibility private
      def initialize(url)
        replace(url)
      end

      # 下载 URL 内容到指定路径的文件或者 IO
      #
      # @param [String, Pathname, #write] io_or_filepath 当给出参数的是字符串或路径时，将 URL 内容写入指定文件。否则将调用 #write 方法将内容写入到指定 IO 中
      # @param [Range] range 文件读取范围
      # @param [Boolean] disable_checksum 禁用校验和（不推荐禁用）
      # @param [Integer, nil] max_retry 最大重试次数，如果设置为 nil，将无限重试
      # @param [Lambda] progress 接受一个进度回调闭包，
      #   该闭包接受两个参数，第一个参数为已经获取的文件内容大小，单位为字节，第二个参数为文件总大小，单位为字节
      # @param [Hash] options 额外的 Down 参数
      # @raise [QiniuNg::Storage::DownloadManager::ChecksumError] 校验和出错
      # @raise [QiniuNg::Storage::DownloadManager::EtagChanged] 下载重试时监测到数据 Etag 发生变化
      def download_to(io_or_filepath, range: nil, disable_checksum: false, max_retry: 5, progress: nil, **options)
        r = reader(range: range, disable_checksum: disable_checksum, max_retry: max_retry, **options)
        handle_io = lambda do |io|
          r.each_chunk(progress: progress) do |chunk|
            chunk_written = 0
            chunk_written += io.write(chunk[chunk_written..-1]) while chunk_written < chunk.bytesize
          end
        end

        if io_or_filepath.is_a?(String) || io_or_filepath.is_a?(Pathname)
          File.open(io_or_filepath, 'wb', &handle_io)
        elsif io_or_filepath
          handle_io.call(io_or_filepath)
        end
        nil
      end

      # 获取包含 URL 内容的阅读器
      #
      # @param [Range] range 文件读取范围
      # @param [Boolean] disable_checksum 禁用校验和（不推荐禁用）
      # @param [Integer, nil] max_retry 最大重试次数，如果设置为 nil，将无限重试
      # @param [Hash] options 额外的 Down 参数
      # @return [QiniuNg::Storage::DownloadManager::Reader] 返回阅读器
      def reader(range: nil, disable_checksum: false, max_retry: 5, **options)
        DownloadManager::Reader.new(self,
                                    range: range, disable_checksum: disable_checksum,
                                    max_retry: max_retry,
                                    backup_url_proc: method(:freeze_current_domain_and_try_another_one),
                                    **options)
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      private

      def freeze_current_domain_and_try_another_one
        nil
      end
    end
  end
end
