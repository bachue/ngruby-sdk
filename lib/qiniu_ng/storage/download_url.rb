# frozen_string_literal: true

require 'webrick'

module QiniuNg
  module Storage
    # 七牛文件的下载地址
    class DownloadURL
      def initialize(domain, key, auth, https: nil)
        @domain = domain
        @key = key
        @auth = auth
        @https = https.nil? ? Config.use_https : https
      end

      def public(filename: nil, fop: nil)
        params = []
        url = @https ? 'https://' : 'http://'
        url += @domain + '/' + WEBrick::HTTPUtils.escape(@key)
        params << [fop] unless fop.nil? || fop.empty?
        params << ['attname', filename] unless filename.nil? || filename.empty?
        url += "?#{Faraday::Utils.build_query(params)}" unless params.empty?
        url
      end

      def private(lifetime: nil, deadline: nil, filename: nil, fop: nil)
        url = public(filename: filename, fop: fop)
        if deadline.nil?
          @auth.sign_download_url_with_deadline(url, deadline: deadline)
        elsif lifetime.nil?
          @auth.sign_download_url_with_lifetime(url, lifetime: lifetime)
        else
          raise ArgumentError, 'Either lifetime or deadline must be specified'
        end
      end
    end
  end
end
