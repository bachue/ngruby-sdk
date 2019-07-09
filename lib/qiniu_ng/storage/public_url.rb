# frozen_string_literal: true

require 'webrick'

module QiniuNg
  module Storage
    # 七牛文件的公开下载地址
    class PublicURL < URL
      attr_reader :domain, :key, :filename, :fop
      def initialize(domain, key, auth, https: nil, filename: nil, fop: nil)
        @domain = domain
        @key = key
        @auth = auth
        @https = https.nil? ? Config.use_https : https
        @filename = filename
        @fop = fop
        @random = nil
        generate_public_url!
      end

      def filename=(filename)
        @filename = filename
        generate_public_url!
      end

      def fop=(fop)
        @fop = fop
        generate_public_url!
      end

      def set(fop: nil, filename: nil)
        @filename = filename unless filename.nil?
        @fop = fop unless fop.nil?
        generate_public_url!
        self
      end

      def private(lifetime: nil, deadline: nil)
        PrivateURL.new(self, @auth, lifetime, deadline)
      end

      def timestamp_anti_leech(encrypt_key:, lifetime: nil, deadline: nil)
        TimestampAntiLeechURL.new(self, encrypt_key, lifetime, deadline)
      end

      def refresh
        @random = Time.now.usec
        generate_public_url!
        self
      end

      private

      def generate_public_url!
        replace(generate_public_url_without_path + generate_public_url_without_domain)
      end

      def generate_public_url_without_path
        url = @https ? 'https://' : 'http://'
        url += @domain
        url
      end

      def generate_public_url_without_domain
        path = '/' + WEBrick::HTTPUtils.escape(@key)
        params = []
        params << [@fop] unless @fop.nil? || @fop.empty?
        params << ['attname', @filename] unless @filename.nil? || @filename.empty?
        params << ['tt', @random] unless @random.nil? || @random.zero?
        path += "?#{Faraday::Utils.build_query(params)}" unless params.empty?
        path
      end
    end
  end
end
