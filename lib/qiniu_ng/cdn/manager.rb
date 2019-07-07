# frozen_string_literal: true

module QiniuNg
  module CDN
    # 七牛 CDN 管理
    class Manager
      # 单个请求最大刷新的链接数量
      MAX_API_REFRESH_URL_COUNT = 100

      # 单个请求最大刷新的前缀数量
      MAX_API_REFRESH_PREFIX_COUNT = 10

      # 单个请求最大预取的链接数量
      MAX_API_PREFETCH_URL_COUNT = 100

      def initialize(http_client_v2)
        @http_client_v2 = http_client_v2
      end

      def cdn_refresh(urls: [], prefixes: [], fusion_url: nil, https: nil, **options)
        refresh_urls = urls.is_a?(Array) ? urls.dup : [urls]
        refresh_dirs = prefixes.is_a?(Array) ? prefixes.dup : [prefixes]
        results = {}
        until refresh_urls.empty? && refresh_dirs.empty?
          req_body = {
            urls: refresh_urls.shift(MAX_API_REFRESH_URL_COUNT),
            dirs: refresh_dirs.shift(MAX_API_REFRESH_PREFIX_COUNT)
          }
          resp_body = @http_client_v2.post('/v2/tune/refresh', fusion_url || get_fusion_url(https),
                                           headers: { content_type: 'application/json' },
                                           body: Config.default_json_marshaler.call(req_body),
                                           **options).body
          results[resp_body['requestId']] = RefreshResult.new(
            request_id: resp_body['requestId'],
            code: resp_body['code'],
            description: resp_body['error'],
            invalid_urls: resp_body['invalidUrls'] || [],
            invalid_prefixes: resp_body['invalidDirs'] || [],
            urls_quota_perday: resp_body['urlQuotaDay'],
            urls_surplus_today: resp_body['urlSurplusDay'],
            prefixes_quota_perday: resp_body['dirQuotaDay'],
            prefixes_surplus_today: resp_body['dirSurplusDay'],
            http_client: @http_client_v2
          )
        end
        results
      end

      private

      def get_fusion_url(https)
        Common::Zone.fusion_url(https)
      end
    end
  end
end
