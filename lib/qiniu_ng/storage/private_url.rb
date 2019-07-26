# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的私有下载地址
    #
    # 该类是 String 的子类，因此可以被当成 String 直接使用，不必调用 #to_s 方法。
    #
    # @!attribute [r] domain
    #   @return [String] 下载地址中的域名
    # @!attribute [r] key
    #   @return [String] 文件名
    # @!attribute filename
    #   @return [String] 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
    # @!attribute fop
    #   @return [String] 数据处理参数。
    class PrivateURL < URL
      extend Forwardable

      # @!visibility private
      def initialize(public_url, auth, lifetime, deadline)
        @public_url = public_url
        @auth = auth
        @lifetime = lifetime
        @deadline = deadline
        generate_private_url!
      end

      def_delegators :@public_url, :domain, :key, :filename, :fop

      # 设置文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      def filename=(filename)
        @public_url.filename = filename
        generate_private_url!
      end

      # 设置数据处理参数
      # @param [String] fop 数据处理参数
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      def fop=(fop)
        @public_url.fop = fop
        generate_private_url!
      end

      # 设置下载地址的过期时间
      #
      # @param [Time] deadline 下载地址过期时间
      def deadline=(deadline)
        @deadline = deadline
        @lifetime = nil
        generate_private_url!
      end

      # 设置下载地址的有效期
      #
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期。
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      def lifetime=(lifetime)
        @lifetime = lifetime
        @deadline = nil
        generate_private_url!
      end

      # 设置下载地址的下载后的文件名和数据处理参数
      #
      # @param [String] fop 数据处理参数
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期。
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @return [QiniuNg::Storage::PrivateURL] 返回上下文
      def set(fop: nil, filename: nil, lifetime: nil)
        @public_url.set(fop: fop, filename: filename)
        self.lifetime = lifetime unless lifetime.nil?
        generate_private_url!
        self
      end

      # 为下载地址带一个随机参数，可以绕过缓存
      #
      # @return [QiniuNg::Storage::PrivateURL] 返回上下文
      def refresh
        @public_url.refresh
        generate_private_url!
        self
      end

      private

      def generate_private_url!
        if @deadline
          replace(@auth.sign_download_url_with_deadline(@public_url, deadline: @deadline))
        else
          lifetime = @lifetime || Config.default_download_url_lifetime
          replace(@auth.sign_download_url_with_lifetime(@public_url, lifetime: lifetime))
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
