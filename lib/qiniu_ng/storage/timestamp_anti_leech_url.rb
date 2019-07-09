# frozen_string_literal: true

require 'digest/md5'
require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的时间戳防盗链下载地址
    class TimestampAntiLeechURL < URL
      extend Forwardable
      def initialize(public_url, encrypt_key, lifetime, deadline)
        @public_url = public_url
        @encrypt_key = encrypt_key
        @deadline = deadline
        @lifetime = lifetime
        generate_timestamp_anti_leech_url!
      end

      def_delegators :@public_url, :domain, :key, :filename, :fop

      def filename=(filename)
        @public_url.filename = filename
        generate_timestamp_anti_leech_url!
      end

      def fop=(fop)
        @public_url.fop = fop
        generate_timestamp_anti_leech_url!
      end

      def deadline=(deadline)
        @deadline = deadline
        @lifetime = nil
        generate_timestamp_anti_leech_url!
      end

      def lifetime=(lifetime)
        @lifetime = lifetime
        @deadline = nil
        generate_timestamp_anti_leech_url!
      end

      def set(fop: nil, filename: nil, lifetime: nil)
        @public_url.set(fop: fop, filename: filename)
        self.lifetime = lifetime unless lifetime.nil?
        generate_timestamp_anti_leech_url!
        self
      end

      def refresh
        @public_url.refresh
        generate_timestamp_anti_leech_url!
        self
      end

      private

      def generate_timestamp_anti_leech_url!
        @deadline ||= Time.now + begin
                                   @lifetime ||= Config.default_download_url_lifetime
                                   @lifetime = Duration.new(@lifetime) if @lifetime.is_a?(Hash)
                                   @lifetime.to_i
                                 end
        deadline_hex = @deadline.to_i.to_s(16)
        url_prefix = @public_url.send(:generate_public_url_without_path)
        path = @public_url.send(:generate_public_url_without_domain)
        to_sign_data = "#{@encrypt_key}#{path.encode('UTF-8')}#{deadline_hex}"
        signed_data = Digest::MD5.hexdigest(to_sign_data)
        if path.include?('?')
          replace("#{url_prefix}#{path}&sign=#{signed_data}&t=#{deadline_hex}")
        else
          replace("#{url_prefix}#{path}?sign=#{signed_data}&t=#{deadline_hex}")
        end
      end
    end
  end
end
