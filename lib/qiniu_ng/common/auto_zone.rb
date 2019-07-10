# frozen_string_literal: true

require 'faraday'

module QiniuNg
  module Common
    # 该类主要用来根据用户提供的 AccessKey 和 Bucket 名称来自动获取有效的区域实例
    class AutoZone
      # @!visibility private
      def initialize
        @client = HTTP.client(domains_manager: HTTP::DomainsManager.new)
        @infer_domains_map = {
          'iovip.qbox.me' => Zone.zone0,
          'iovip-z1.qbox.me' => Zone.zone1,
          'iovip-z2.qbox.me' => Zone.zone2,
          'iovip-na0.qbox.me' => Zone.zone_na0,
          'iovip-as0.qbox.me' => Zone.zone_as0
        }
      end

      # 查询区域
      # @example
      #   zone = QiniuNg::Zone.auto.query(access_key: '<Qiniu AccessKey>', bucket: '<Bucket Name>')
      #
      # @param [String] access_key 七牛 AccessKey
      # @param [String] bucket 七牛 Bucket 名称
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Zone] 返回包含查询结果的区域
      def query(access_key:, bucket:, https: nil, **options)
        body = @client.get('/v2/query', api_url(https), params: { ak: access_key, bucket: bucket }, **options).body

        up_hosts = body['up']&.values_at('acc', 'src', 'old_acc', 'old_src')
                             &.map { |region| region&.values_at('main', 'backup') }&.flatten&.compact
        up_http_urls = up_hosts.map { |domain| "http://#{domain}" }
        up_https_urls = up_hosts.map { |domain| "https://#{domain}" }

        io_hosts = body.dig('io', 'src', 'main')
        io_http_urls = io_hosts.map { |domain| "http://#{domain}" }
        io_https_urls = io_hosts.map { |domain| "https://#{domain}" }

        region = @infer_domains_map[io_hosts.first]&.region
        rs_http_url = @infer_domains_map[io_hosts.first]&.rs_http_url
        rs_https_url = @infer_domains_map[io_hosts.first]&.rs_https_url
        rsf_http_url = @infer_domains_map[io_hosts.first]&.rsf_http_url
        rsf_https_url = @infer_domains_map[io_hosts.first]&.rsf_https_url
        api_http_url = @infer_domains_map[io_hosts.first]&.api_http_url
        api_https_url = @infer_domains_map[io_hosts.first]&.api_https_url
        Zone.new(region: region,
                 up_http_urls: up_http_urls&.freeze,
                 up_https_urls: up_https_urls&.freeze,
                 io_http_urls: io_http_urls&.freeze,
                 io_https_urls: io_https_urls&.freeze,
                 rs_http_url: rs_http_url&.freeze,
                 rs_https_url: rs_https_url&.freeze,
                 rsf_http_url: rsf_http_url&.freeze,
                 rsf_https_url: rsf_https_url&.freeze,
                 api_http_url: api_http_url&.freeze,
                 api_https_url: api_https_url&.freeze).freeze
      end

      private

      def api_url(https)
        https = Config.use_https if https.nil?
        Common::Zone.huadong.api_url(https)
      end
    end
  end
end
