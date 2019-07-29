# frozen_string_literal: true

require 'digest/md5'
require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的时间戳防盗链下载地址
    #
    # 该类是 String 的子类，因此可以被当成 String 直接使用，不必调用 #to_s 方法。
    #
    class TimestampAntiLeechURL < URL
      extend Forwardable

      # @!visibility private
      def initialize(public_url, encrypt_key, lifetime, deadline)
        @public_url = public_url
        @encrypt_key = encrypt_key
        @deadline = deadline
        @lifetime = lifetime
        generate_timestamp_anti_leech_url!
      end

      def_delegators :@public_url, :domain, :key, :filename, :fop

      # 设置文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      def filename=(filename)
        @public_url.filename = filename
        generate_timestamp_anti_leech_url!
      end

      # 设置数据处理参数
      # @param [String] fop 数据处理参数，设置该参数将使 style 设置被移除。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      def fop=(fop)
        @public_url.fop = fop
        generate_timestamp_anti_leech_url!
      end

      # 设置数据处理样式
      # @param [String] style 数据处理样式，设置该参数将使 fop 设置被移除。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      def style=(style)
        @public_url.style = style
        generate_timestamp_anti_leech_url!
      end

      # 设置下载地址的过期时间
      #
      # @param [Time] deadline 下载地址过期时间
      def deadline=(deadline)
        @deadline = deadline
        @lifetime = nil
        generate_timestamp_anti_leech_url!
      end

      # 设置下载地址的有效期
      #
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期。
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      def lifetime=(lifetime)
        @lifetime = lifetime
        @deadline = nil
        generate_timestamp_anti_leech_url!
      end

      # 设置下载地址的下载后的文件名和数据处理参数
      #
      # @param [String] fop 数据处理参数，不要与 style 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] style 数据处理样式，不要与 fop 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期。
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @return [QiniuNg::Storage::PrivateURL] 返回上下文
      def set(fop: nil, style: nil, filename: nil, lifetime: nil)
        @public_url.set(fop: fop, style: style, filename: filename)
        self.lifetime = lifetime unless lifetime.nil?
        generate_timestamp_anti_leech_url!
        self
      end

      # 为下载地址带一个随机参数，可以绕过缓存
      #
      # @return [QiniuNg::Storage::PrivateURL] 返回上下文
      def refresh
        @public_url.refresh
        generate_timestamp_anti_leech_url!
        self
      end

      private

      def generate_timestamp_anti_leech_url!
        @deadline ||= Time.now + begin
                                   @lifetime ||= Config.default_download_url_lifetime
                                   @lifetime = Utils::Duration.new(@lifetime) if @lifetime.is_a?(Hash)
                                   @lifetime.to_i
                                 end
        deadline_hex = @deadline.to_i.to_s(16).downcase
        url_prefix = @public_url.send(:generate_public_url_without_path)
        path = @public_url.send(:generate_public_url_without_domain)
        to_sign_data = "#{@encrypt_key}#{path.encode('UTF-8')}#{deadline_hex}"
        signed_data = Digest::MD5.hexdigest(to_sign_data).downcase
        if path.include?('?')
          replace("#{url_prefix}#{path}&sign=#{signed_data}&t=#{deadline_hex}")
        else
          replace("#{url_prefix}#{path}?sign=#{signed_data}&t=#{deadline_hex}")
        end
      end

      def freeze_current_domain_and_try_another_one
        result = super
        return nil if result.nil?

        generate_private_url!
      end
    end
  end
end
