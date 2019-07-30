# frozen_string_literal: true

require 'webrick'

module QiniuNg
  module Storage
    # 七牛文件的公开下载地址
    #
    # 该类是 String 的子类，因此可以被当成 String 直接使用，不必调用 #to_s 方法。
    #
    # @example 下载公开空间中的文件
    #   Faraday.get(client.bucket('<Bucket Name>')
    #                     .entry('<key>')
    #                     .download_url)
    # @example 下载私有空间中的文件
    #   Faraday.get(client.bucket('<Bucket Name>')
    #                     .entry('<key>')
    #                     .download_url.private)
    # @example 下载 CDN 中 生成带有时间戳鉴权的文件
    #   Faraday.get(client.bucket('<Bucket Name>')
    #                     .entry('<key>')
    #                     .download_url
    #                     .timestamp_anti_leech(encrypt_key: '<EncryptKey>'))
    #
    # @!attribute [r] domains
    #   @return [Array<String>] 下载地址中的域名列表
    # @!attribute [r] key
    #   @return [String] 文件名
    # @!attribute filename
    #   @return [String] 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
    # @!attribute fop
    #   @return [String] 数据处理参数，与 style 不要同时设置。
    #     {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
    # @!attribute style
    #   @return [String] 数据处理样式，与 fop 不要同时设置。
    #     {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
    class PublicURL < URL
      attr_reader :domains, :key, :filename, :fop

      # @!visibility private
      def initialize(domains, key, auth, style_separator:, https: nil, filename: nil, fop: nil, style: nil)
        @domains = domains
        @current_domain = nil
        @key = key
        @auth = auth
        @style_separator = style_separator
        @https = https.nil? ? Config.use_https : https
        @filename = filename.to_s
        @fop = fop
        @style = style
        @random = nil
        generate_public_url!
      end

      # 设置文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      def filename=(filename)
        @filename = filename.to_s
        generate_public_url!
      end

      # 设置数据处理参数
      # @param [String] fop 数据处理参数，设置该参数将使 style 设置被移除。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      def fop=(fop)
        @fop = fop
        @style = nil
        generate_public_url!
      end

      # 设置数据处理样式
      # @param [String] style 数据处理样式，设置该参数将使 fop 设置被移除。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      def style=(style)
        @fop = nil
        @style = style
        generate_public_url!
      end

      # 设置下载地址的下载后的文件名和数据处理参数
      #
      # @param [String] fop 数据处理参数，不要与 style 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] style 数据处理样式，不要与 fop 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] filename 文件下载后的文件名。该参数仅对由浏览器打开的地址有效
      # @return [QiniuNg::Storage::PublicURL] 返回上下文
      def set(fop: nil, style: nil, filename: nil)
        @filename = filename.to_s unless filename.nil?
        @fop = fop unless fop.nil?
        @style = style unless style.nil?
        generate_public_url!
        self
      end

      # 为私有空间生成下载地址
      #
      # @example
      #   client.bucket('<Bucket Name>').entry('<key>').download_url.private(lifetime: { hour: 1 })
      #
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期，与 deadline 参数不要同时使用
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @param [Time] deadline 下载地址过期时间，与 lifetime 参数不要同时使用
      # @return [QiniuNg::Storage::PrivateURL] 返回私有空间的文件下载地址
      def private(lifetime: nil, deadline: nil)
        PrivateURL.new(self, @auth, lifetime, deadline)
      end

      # 为 CDN 生成带有时间戳鉴权的下载地址
      #
      # @example
      #   client.bucket('<Bucket Name>').entry('<key>').download_url.timestamp_anti_leech(encrypt_key: '<EncryptKey>')
      # @see https://developer.qiniu.com/kodo/manual/1657/download-anti-leech
      #
      # @param [String] encrypt_key CDN Key
      #   {参考文档}[https://developer.qiniu.com/fusion/kb/1670/timestamp-hotlinking-prevention]
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期，与 deadline 参数不要同时使用
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @param [Time] deadline 下载地址过期时间，与 lifetime 参数不要同时使用
      # @return [QiniuNg::Storage::TimestampAntiLeechURL] 返回带有时间戳鉴权的下载地址
      def timestamp_anti_leech(encrypt_key:, lifetime: nil, deadline: nil)
        TimestampAntiLeechURL.new(self, encrypt_key, lifetime, deadline)
      end

      # 为下载地址带一个随机参数，可以绕过缓存
      #
      # @return [QiniuNg::Storage::PublicURL] 返回上下文
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
        raise HTTP::NoURLAvailable if frozen?

        current_domain = @domains.find { |domain| !Config.default_domains_manager.frozen?(domain) }
        raise HTTP::NoURLAvailable if current_domain.nil?

        @current_domain = current_domain
        url = @https ? 'https://' : 'http://'
        url += current_domain
        url
      end

      def generate_public_url_without_domain
        path = '/' + WEBrick::HTTPUtils.escape(@key)
        params = []
        if !@fop.nil? && !@fop.empty?
          params << [@fop]
        elsif !@style.nil? && !@style.empty?
          path += @style_separator + WEBrick::HTTPUtils.escape(@style)
        end
        params << ['attname', @filename] unless @filename.nil? || @filename.empty?
        params << ['tt', @random] unless @random.nil? || @random.zero?
        path += "?#{Faraday::Utils.build_query(params)}" unless params.empty?
        path
      end

      def freeze_current_domain_and_try_another_one
        Config.default_domains_manager.freeze(@current_domain) if @current_domain

        generate_public_url!
      rescue HTTP::NoURLAvailable
        nil
      end
    end
  end
end
