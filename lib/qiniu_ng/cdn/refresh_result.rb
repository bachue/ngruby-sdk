# frozen_string_literal: true

module QiniuNg
  module CDN
    # 七牛 CDN 刷新结果
    class RefreshResult
      attr_reader :request_id, :code, :description, :invalid_urls, :invalid_prefixes, :urls_quota_perday,
                  :urls_surplus_today, :prefixes_quota_perday, :prefixes_surplus_today
      def initialize(request_id:, code:, description:, invalid_urls:, invalid_prefixes:, urls_quota_perday:,
                     urls_surplus_today:, prefixes_quota_perday:, prefixes_surplus_today:, http_client:)
        @request_id = request_id
        @code = code
        @description = description
        @invalid_urls = invalid_urls
        @invalid_prefixes = invalid_prefixes
        @urls_quota_perday = urls_quota_perday
        @urls_surplus_today = urls_surplus_today
        @prefixes_quota_perday = prefixes_quota_perday
        @prefixes_surplus_today = prefixes_surplus_today
        @http_client = http_client
      end

      def ok?
        @code == 200
      end

      def query(fusion_url: nil, https: nil, **options)
        QueryBuilder.new(@http_client, @request_id, fusion_url: fusion_url, https: https, **options)
      end

      def inspect
        "<#{self.class.name} @request_id=#{@request_id.inspect} @code=#{@code.inspect}" \
        " @description=#{@description.inspect} @invalid_urls=#{@invalid_urls.inspect}" \
        " @invalid_prefixes=#{@invalid_prefixes.inspect} @urls_quota_perday=#{@urls_quota_perday.inspect}" \
        " @urls_surplus_today=#{@urls_surplus_today.inspect} @prefixes_quota_perday=#{@prefixes_quota_perday.inspect}" \
        " @prefixes_surplus_today=#{@prefixes_surplus_today.inspect}>"
      end

      # 刷新查询结果
      class QueryResult
        attr_reader :request_id, :url, :state, :state_detail, :created_at, :begin_at, :end_at
        def initialize(request_id:, url:, state:, state_detail:, created_at:, begin_at:, end_at:, is_prefix:)
          @request_id = request_id
          @url = url
          @state = state
          @state_detail = state_detail
          @created_at = created_at
          @begin_at = begin_at
          @end_at = end_at
          @is_prefix = is_prefix
        end

        def prefix?
          Utils::Bool.to_bool(@is_prefix)
        end
      end

      # 刷新查询条件构建
      class QueryBuilder
        include Enumerable

        def initialize(http_client, request_id, fusion_url: nil, https: nil, **options)
          @http_client = http_client
          @request_id = request_id
          @include_prefixes = nil
          @urls = nil
          @state = nil
          @fusion_url = fusion_url
          @https = https
          @options = options
        end

        def include_prefixes
          @include_prefixes = true
          self
        end

        def exclude_prefixes
          @include_prefixes = false
          self
        end

        def only_urls(urls)
          urls = [urls] unless urls.is_a?(Array)
          @urls = urls
          self
        end

        def only_processing
          @state = 'processing'
          self
        end

        def only_successful
          @state = 'success'
          self
        end

        def only_failed
          @state = 'failure'
          self
        end

        def each
          return enumerator unless block_given?

          enumerator.each do |entry|
            yield entry
          end
        end

        private

        def enumerator
          body = { requestId: @request_id }
          body[:isDir] = @include_prefixes ? 'yes' : 'no' unless @include_prefixes.nil?
          body[:urls] = @urls unless @urls.nil?
          body[:state] = @state unless @state.nil?

          got = 0
          total = nil
          page_no = 0

          Enumerator.new do |yielder|
            while total.nil? || got < total
              resp = @http_client.post('/v2/tune/refresh/list', @fusion_url || get_fusion_url(@https),
                                       headers: { content_type: 'application/json' },
                                       body: Config.default_json_marshaler.call(body.merge(pageNo: page_no)),
                                       **@options)
              raise RefreshQueryError, response_values(resp) unless resp.body['code'] == 200

              page_no += 1
              total = resp.body['total']
              resp.body['items']&.each do |item|
                got += 1
                yielder << QueryResult.new(
                  request_id: item['requestId'], url: item['url'], state: item['state'],
                  state_detail: item['stateDetail'], created_at: Time.parse(item['createAt']),
                  begin_at: Time.parse(item['beginAt']), end_at: Time.parse(item['endAt']),
                  is_prefix: item['isDir'] == 'yes'
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
