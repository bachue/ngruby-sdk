# frozen_string_literal: true

module QiniuNg
  module CDN
    # 七牛 CDN 日志文件
    #
    # 该类封装了一个日志文件
    #
    # @!attribute [r] name
    #   @return [String] 日志文件的文件名
    # @!attribute [r] size
    #   @return [Integer] 日志文件的大小，单位为字节
    # @!attribute [r] created_at
    #   @return [Time] 日志文件的创建时间（不代表日志记录的时间）
    # @!attribute [r] url
    #   @return [QiniuNg::Storage::URL] 日志文件的下载地址
    # @!attribute [r] md5
    #   @return [String] 日志文件的 MD5 校验和
    class LogFile
      attr_reader :name, :size, :created_at, :url, :md5

      # @!visibility private
      def initialize(hash)
        @name = hash['name']
        @size = hash['size']
        @created_at = Time.at(hash['mtime'])
        @url = Storage::URL.new(hash['url'])
        @md5 = hash['md5']
      end
    end
  end
end
