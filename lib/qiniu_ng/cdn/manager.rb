# frozen_string_literal: true

require 'ruby-enum'

module QiniuNg
  module CDN
    # 七牛 CDN 管理
    #
    # 该类所有方法都已被委托给 QiniuNg::Client 直接调用
    class Manager
      # 单个请求最大刷新的链接数量
      MAX_API_REFRESH_URL_COUNT = 100

      # 单个请求最大刷新的前缀数量
      MAX_API_REFRESH_PREFIX_COUNT = 10

      # 单个请求最大预取的链接数量
      MAX_API_PREFETCH_URL_COUNT = 100

      # @!visibility private
      def initialize(http_client_v2)
        @http_client_v2 = http_client_v2
      end

      # 刷新 CDN 地址，删除客户资源在 CDN 节点的缓存
      #
      # 请给出资源 URL 完整的绝对路径，由 http:// 或 https:// 开始
      #
      # 带参数的 url 刷新，根据其域名缓存配置是否忽略参数缓存决定刷新结果。如果配置了时间戳防盗链的资源 url 提交时刷新需要去掉 sign 和 t 参数。
      #
      # 当前目录刷新权限默认关闭，如需开通权限请通过工单联系七牛云审核开通。
      #
      # 注意，每天刷新请求次数都有限额，请谨慎调用本 API。
      #
      # @example
      #   requests = client.cdn_refresh(urls: entries.map(&:download_url))
      #   requests.each do |request_id, request|
      #     request.results.each do |result|
      #       expect(result.failure?).to be false
      #     end
      #   end
      #
      # @param [Array<String>, String] urls 刷新的 URL 列表
      # @param [Array<String>, String] prefixes 刷新的 URL 目录列表，需要以 "/" 结尾
      # @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Hash<String, QiniuNg::CDN::RefreshRequest>] 返回刷新结果集合，
      #   由于 API 对单次刷新的 URL 和列表个数都有一定限制，因此 SDK 会在参数个数超过限制时分多次请求。因此可能会得到多个刷新结果。
      #   刷新结果将以 Hash 形式返回，Key 为刷新请求得到的 RequestID，而 Value 为刷新结果
      def cdn_refresh(urls: [], prefixes: [], fusion_url: nil, https: nil, **options)
        refresh_urls = urls.is_a?(Array) ? urls.dup : [urls].compact
        refresh_dirs = prefixes.is_a?(Array) ? prefixes.dup : [prefixes].compact
        requests = {}
        until refresh_urls.empty? && refresh_dirs.empty?
          req_body = {
            urls: refresh_urls.shift(MAX_API_REFRESH_URL_COUNT),
            dirs: refresh_dirs.shift(MAX_API_REFRESH_PREFIX_COUNT)
          }
          resp_body = @http_client_v2.post('/v2/tune/refresh', fusion_url || get_fusion_url(https),
                                           idempotent: true, headers: { content_type: 'application/json' },
                                           body: Config.default_json_marshaler.call(req_body),
                                           **options).body
          requests[resp_body['requestId']] = RefreshRequest.new(
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
        requests
      end

      # 预取文件，提前将新上传的文件由 CDN 拉取到 CDN 缓存节点
      #
      # 请给出资源 URL 完整的绝对路径，由 http:// 或 https:// 开始
      #
      # 注意，每天预取请求次数都有限额，请谨慎调用本 API。
      #
      # @example
      #   requests = client.cdn_prefetch(entries.map(&:download_url))
      #   requests.each do |request_id, request|
      #     request.results.each do |result|
      #       expect(result.failure?).to be false
      #     end
      #   end
      #
      # @param [Array<String>, String] urls 预取的 URL 列表
      # @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Hash<String, QiniuNg::CDN::PrefetchRequest>] 返回预取请求集合，
      #   由于 API 对单次预取的 URL 和列表个数都有一定限制，因此 SDK 会在参数个数超过限制时分多次请求。因此可能会得到多个预取请求。
      #   预取请求将以 Hash 形式返回，Key 为预取请求得到的 RequestID，而 Value 为预取请求
      def cdn_prefetch(urls, fusion_url: nil, https: nil, **options)
        prefetch_urls = urls.is_a?(Array) ? urls.dup : [urls].compact
        requests = {}
        until prefetch_urls.empty?
          req_body = { urls: prefetch_urls.shift(MAX_API_PREFETCH_URL_COUNT) }
          resp_body = @http_client_v2.post('/v2/tune/prefetch', fusion_url || get_fusion_url(https),
                                           idempotent: true, headers: { content_type: 'application/json' },
                                           body: Config.default_json_marshaler.call(req_body),
                                           **options).body
          requests[resp_body['requestId']] = PrefetchRequest.new(
            request_id: resp_body['requestId'], code: resp_body['code'], description: resp_body['error'],
            invalid_urls: resp_body['invalidUrls'] || [],
            quota_perday: resp_body['quotaDay'], surplus_today: resp_body['surplusDay'],
            http_client: @http_client_v2
          )
        end
        requests
      end

      # rubocop:disable Metrics/LineLength

      # @!method cdn_bandwidth_log(start_time:, end_time:, granularity:, domains:, fusion_url: nil, https: nil, **options)
      #   批量查询 CDN 带宽
      #
      #   @example
      #     client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #     log = client.cdn_bandwith_log(start_time: 5.days.ago, end_time: Time.now, granularity: :day, domains: [<domain1>, <domain2>])
      #     p log.to_a
      #
      #   @param [Time] start_time 日志开始时间
      #   @param [Time] end_time 日志结束时间
      #   @param [Symbol, String] granularity 粒度，只能接受 :'5min'，:hour，:day 三种值
      #   @param [Array<String>, String] domains 域名列表
      #   @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      #   @param [Boolean] https 是否使用 HTTPS 协议
      #   @param [Hash] options 额外的 Faraday 参数
      #   @raise [QiniuNg::CDN::Error::LogQueryError] 查询日志失败，部分参数可能存在存在错误
      #   @return [QiniuNg::CDN::Log] 返回日志对象实例

      # @!method cdn_flux_log(start_time:, end_time:, granularity:, domains:, fusion_url: nil, https: nil, **options)
      #   批量查询 CDN 流量
      #
      #   @example
      #     client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #     log = client.cdn_flux_log(start_time: 5.days.ago, end_time: Time.now, granularity: :day, domains: [<domain1>, <domain2>])
      #     p log.to_a
      #
      #   @param [Time] start_time 日志开始时间
      #   @param [Time] end_time 日志结束时间
      #   @param [Symbol, String] granularity 粒度，只能接受 :'5min'，:hour，:day 三种值
      #   @param [Array<String>, String] domains 域名列表
      #   @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      #   @param [Boolean] https 是否使用 HTTPS 协议
      #   @param [Hash] options 额外的 Faraday 参数
      #   @raise [QiniuNg::CDN::Error::LogQueryError] 查询日志失败，部分参数可能存在存在错误
      #   @return [QiniuNg::CDN::Log] 返回日志对象实例

      # rubocop:enable Metrics/LineLength

      %i[bandwidth flux].each do |name|
        # rubocop:disable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters
        define_method(:"cdn_#{name}_log") do |start_time:, end_time:, granularity:, domains:,
                                              fusion_url: nil, https: nil, **options|
          # rubocop:enable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters
          domains = normalize_domains(domains)
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
          raise LogQueryError, response_values(resp) unless resp.body['code'] == 200

          Log.new(resp.body['time'] || [], resp.body['data'] || {})
        end
      end

      # 获取 CDN 访问日志下载地址
      #
      # 只提供 30 个自然日内的日志下载。
      #
      # 日志文件默认按小时下载，如果单小时内日志过大会进行切分（分片大小128MB），日志文件采用 gzip 压缩。
      #
      # 日志大概延迟6小时，举例：1 月 18 日 0 点 - 1 点的日志，会在 1 月 18 日 8 点 - 10 点左右可下载。
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   log = client.cdn_access_logs(time: 5.days.ago, domains: [<domain1>, <domain2>])
      #   log.each do |domain, log_files|
      #     log_files.each do |log_file|
      #       puts log_file.url
      #     end
      #   end
      #
      # @param [Time] time CDN 日志时间
      # @param [Array<String>, String] domains 域名列表
      # @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::CDN::Error::LogQueryError] 查询日志失败，部分参数可能存在存在错误
      # @return [QiniuNg::CDN::LogFiles] 返回日志对象实例
      def cdn_access_logs(time:, domains:, fusion_url: nil, https: nil, **options)
        domains = normalize_domains(domains)
        req_body = { day: time.strftime('%Y-%m-%d'), domains: domains.join(';') }
        resp = @http_client_v2.post('/v2/tune/log/list', fusion_url || get_fusion_url(https),
                                    idempotent: true, headers: { content_type: 'application/json' },
                                    body: Config.default_json_marshaler.call(req_body),
                                    **options)
        raise LogQueryError, response_values(resp) unless resp.body['code'] == 200

        LogFiles.new(resp.body['data'])
      end

      private

      def response_values(response)
        { status: response.status, headers: response.headers, body: response.body }
      end

      def normalize_domains(domains)
        domains = [domains] unless domains.nil? || domains.is_a?(Array)
        domains&.map { |domain| domain.sub(%r{^\w+://}, '') }
      end

      def get_fusion_url(https)
        Common::Zone.fusion_url(https)
      end
    end
  end
end
