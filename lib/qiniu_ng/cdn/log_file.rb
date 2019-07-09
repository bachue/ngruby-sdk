# frozen_string_literal: true

module QiniuNg
  module CDN
    # 七牛 CDN 日志文件
    class LogFile
      attr_reader :name, :size, :log_at, :url, :md5

      def initialize(hash)
        @name = hash['name']
        @size = hash['size']
        @log_at = Time.at(hash['mtime'])
        @url = Storage::URL.new(hash['url'])
        @md5 = hash['md5']
      end
    end
  end
end
