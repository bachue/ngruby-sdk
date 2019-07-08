# frozen_string_literal: true

require 'ruby-enum'

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
                                           idempotent: true, headers: { content_type: 'application/json' },
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

      def cdn_prefetch(urls, fusion_url: nil, https: nil, **options)
        prefetch_urls = urls.is_a?(Array) ? urls.dup : [urls]
        results = {}
        until prefetch_urls.empty?
          req_body = { urls: prefetch_urls.shift(MAX_API_PREFETCH_URL_COUNT) }
          resp_body = @http_client_v2.post('/v2/tune/prefetch', fusion_url || get_fusion_url(https),
                                           idempotent: true, headers: { content_type: 'application/json' },
                                           body: Config.default_json_marshaler.call(req_body),
                                           **options).body
          results[resp_body['requestId']] = PrefetchResult.new(
            request_id: resp_body['requestId'], code: resp_body['code'], description: resp_body['error'],
            invalid_urls: resp_body['invalidUrls'] || [],
            quota_perday: resp_body['quotaDay'], surplus_today: resp_body['surplusDay'],
            http_client: @http_client_v2
          )
        end
        results
      end

      %i[bandwidth flux].each do |name|
        # rubocop:disable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters
        define_method(:"cdn_#{name}_log") do |start_time:, end_time:, granularity:, domains:,
                                              fusion_url: nil, https: nil, **options|
          # rubocop:enable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters
          domains = domains.is_a?(Array) ? domains.dup : [domains]
          granularity = Granularity.value(granularity.to_sym)
          if granularity.nil?
            raise ArgumentError, 'granularity is invalid, only `:\'5min\'`, `:hour` and `:day` are acceptable'
          end

          req_body = {
            startDate: start_time.strftime('%Y-%m-%d'), endDate: end_time.strftime('%Y-%m-%d'),
            granularity: granularity, domains: domains.join(';')
          }
          resp = @http_client_v2.post("/v2/tune/#{name}", fusion_url || get_fusion_url(https),
                                      idempotent: true, headers: { content_type: 'application/json' },
                                      body: Config.default_json_marshaler.call(req_body),
                                      **options)
          raise QueryError, response_values(resp) unless resp.body['code'] == 200

          Log.new(resp.body['time'] || [], resp.body['data'] || {})
        end
      end

      private

      def response_values(response)
        { status: response.status, headers: response.headers, body: response.body }
      end

      def get_fusion_url(https)
        Common::Zone.fusion_url(https)
      end
    end
  end
end
