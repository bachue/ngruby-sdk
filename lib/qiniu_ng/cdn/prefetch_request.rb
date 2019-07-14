# frozen_string_literal: true

module QiniuNg
  module CDN
    # 七牛 CDN 预取请求
    #
    # @!attribute [r] request_id
    #   @return [String] 预取请求 ID
    # @!attribute [r] code
    #   @return [Integer] 预取结果响应状态码。
    #    {参考文档}[https://developer.qiniu.com/fusion/api/1227/file-prefetching#prefetch-response-status]
    # @!attribute [r] description
    #   @return [String] 自定义状态码描述信息
    # @!attribute [r] invalid_urls
    #   @return [Array<String>] 无效的 URL 列表
    # @!attribute [r] quota_perday
    #   @return [Integer] 每天预取 URL 限额
    # @!attribute [r] surplus_today
    #   @return [Integer] 当日剩余的预取 URL 限额
    class PrefetchRequest
      attr_reader :request_id, :code, :description, :invalid_urls, :quota_perday, :surplus_today
      alias id request_id

      # @!visibility private
      def initialize(request_id:, code:, description:, invalid_urls:, quota_perday:, surplus_today:, http_client:)
        @request_id = request_id
        @code = code
        @description = description
        @invalid_urls = invalid_urls
        @quota_perday = quota_perday
        @surplus_today = surplus_today
        @http_client = http_client
      end

      # 预取是否成功请求
      #
      # @return [Boolean] 预取是否成功
      def ok?
        @code == 200
      end

      # 查询预取结果
      #
      # @example
      #   requests = client.cdn_prefetch(entries.map(&:download_url))
      #   requests.each do |request_id, request|
      #     request.results.each do |result|
      #       expect(result.failure?).to be false
      #     end
      #   end
      #
      # @param [String] fusion_url Fusion 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::CDN::PrefetchRequest::QueryBuilder] 预取结果查询条件构建器
      def results(fusion_url: nil, https: nil, **options)
        QueryBuilder.new(@http_client, @request_id, fusion_url: fusion_url, https: https, **options)
      end

      # @!visibility private
      def inspect
        "<#{self.class.name} @request_id=#{@request_id.inspect} @code=#{@code.inspect}" \
        " @description=#{@description.inspect} @invalid_urls=#{@invalid_urls.inspect}" \
        " @quota_perday=#{@quota_perday.inspect} @surplus_today=#{@surplus_today.inspect}>"
      end

      # 预取查询结果
      # @!attribute [r] request_id
      #   @return [String] 预取请求 ID
      # @!attribute [r] url
      #   @return [QiniuNg::Storage::URL] 预取请求的 URL
      # @!attribute [r] state
      #   @return [String] 预取状态，取值为 success，processing，failure
      # @!attribute [r] state_detail
      #   @return [String] 预取状态描述信息
      # @!attribute [r] created_at
      #   @return [Time] 当前记录创建时间
      # @!attribute [r] begin_at
      #   @return [Time] 当前记录开始时间
      # @!attribute [r] end_at
      #   @return [Time] 当前记录结束时间
      class QueryResult
        attr_reader :request_id, :url, :state, :state_detail, :created_at, :begin_at, :end_at

        # @!visibility private
        def initialize(request_id:, url:, state:, state_detail:, created_at:, begin_at:, end_at:)
          @request_id = request_id
          @url = url
          @state = state
          @state_detail = state_detail
          @created_at = created_at
          @begin_at = begin_at
          @end_at = end_at
        end

        # 预取是否成功
        #
        # @return [Boolean] 预取是否成功
        def successful?
          @state == 'success'
        end

        # 预取是否在处理中
        #
        # @return [Boolean] 预取是否在处理中
        def processing?
          @state == 'processing'
        end

        # 预取是否失败
        #
        # @return [Boolean] 预取是否失败
        def failed?
          @state == 'failure'
        end
      end

      # 预取结果查询条件构建器
      class QueryBuilder
        include Enumerable

        # @!visibility private
        def initialize(http_client, request_id, fusion_url: nil, https: nil, **options)
          @http_client = http_client
          @request_id = request_id
          @invalid_urls = nil
          @quota_perday = nil
          @surplus_today = nil
          @urls = nil
          @state = nil
          @fusion_url = fusion_url
          @https = https
          @options = options
        end

        # 仅查询指定 URL 的预取结果
        #
        # @param [Array<String>, String] urls 查询指定 URL
        # @return [QiniuNg::CDN::PrefetchRequest::QueryBuilder] 返回上下文
        def only_urls(urls)
          urls = [urls] unless urls.is_a?(Array)
          @urls = urls
          self
        end
        alias only_url only_urls

        # 仅查询仍在处理中的预期结果
        #
        # @return [QiniuNg::CDN::PrefetchRequest::QueryBuilder] 返回上下文
        def only_processing
          @state = 'processing'
          self
        end

        # 仅查询成功的的预期结果
        #
        # @return [QiniuNg::CDN::PrefetchRequest::QueryBuilder] 返回上下文
        def only_successful
          @state = 'success'
          self
        end

        # 仅查询失败的预期结果
        #
        # @return [QiniuNg::CDN::PrefetchRequest::QueryBuilder] 返回上下文
        def only_failed
          @state = 'failure'
          self
        end

        # 对查询结果进行迭代
        #
        # @yield [entry] 传入 Block 对结果进行迭代
        # @yieldparam [QiniuNg::CDN::PrefetchRequest::QueryResult] 查询结果
        # @return [Enumerable] 如果没有给出 Block，则返回迭代器
        def each
          return enumerator unless block_given?

          enumerator.each do |entry|
            yield entry
          end
        end

        private

        def enumerator
          body = { requestId: @request_id }
          body[:urls] = @urls unless @urls.nil?
          body[:state] = @state unless @state.nil?

          got = 0
          total = nil
          page_no = 0

          Enumerator.new do |yielder|
            while total.nil? || got < total
              resp = @http_client.post('/v2/tune/prefetch/list', @fusion_url || get_fusion_url(@https),
                                       headers: { content_type: 'application/json' },
                                       body: Config.default_json_marshaler.call(body.merge(pageNo: page_no)),
                                       **@options)
              raise PrefetchQueryError, response_values(resp) unless resp.body['code'] == 200

              page_no += 1
              total = resp.body['total']
              resp.body['items']&.each do |item|
                got += 1
                yielder << QueryResult.new(
                  request_id: item['requestId'], url: Storage::URL.new(item['url']), state: item['state'],
                  state_detail: item['stateDetail'], created_at: Time.parse(item['createAt']),
                  begin_at: Time.parse(item['beginAt']), end_at: Time.parse(item['endAt'])
                )
              end
            end
          end
        end

        def get_fusion_url(https)
          Common::Zone.fusion_url(https)
        end

        def response_values(response)
          { status: response.status, headers: response.headers, body: response.body }
        end
      end
    end
  end
end
