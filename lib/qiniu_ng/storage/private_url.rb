# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的私有下载地址
    class PrivateURL < String
      extend Forwardable
      def initialize(public_url, auth, lifetime, deadline)
        @public_url = public_url
        @auth = auth
        @lifetime = lifetime
        @deadline = deadline
        generate_private_url
      end

      def_delegators :@public_url, :domain, :key, :filename, :fop

      def inspect
        "#<#{self.class.name} #{self}>"
      end

      def filename=(filename)
        @public_url.filename = filename
        generate_private_url
      end

      def fop=(fop)
        @public_url.fop = fop
        generate_private_url
      end

      def deadline=(deadline)
        @deadline = deadline
        @lifetime = nil
        generate_private_url
      end

      def lifetime=(lifetime)
        @lifetime = lifetime
        @deadline = nil
        generate_private_url
      end

      def set(fop: nil, filename: nil, lifetime: nil)
        @public_url.set(fop: fop, filename: filename)
        self.lifetime = lifetime unless lifetime.nil?
        generate_private_url
        self
      end

      def refresh
        @public_url.refresh
        generate_private_url
        self
      end

      private

      def generate_private_url
        if !@deadline.nil? && @deadline.positive?
          replace(@auth.sign_download_url_with_deadline(@public_url, deadline: @deadline))
        else
          lifetime = @lifetime || Config.default_download_url_lifetime
          replace(@auth.sign_download_url_with_lifetime(@public_url, lifetime: lifetime))
        end
      end
    end
  end
end
