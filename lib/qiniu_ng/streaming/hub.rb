# frozen_string_literal: true

module QiniuNg
  module Streaming
    # 七牛直播空间
    #
    # @example
    #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
    #   streams = client.hub('<Hub Name>', domain: '<Hub Domain>').streams
    #
    # @!attribute [r] name
    #   @return [String] 直播空间名称
    class Hub
      attr_reader :name
      # @!visibility private
      def initialize(hub, http_client_v2, auth, domain)
        @name = hub
        @auth = auth
        @http_client_v2 = http_client_v2
        @domain = domain
      end

      # 获取直播流
      #
      # @param [String] key 直播流名称
      # @return [Stream] 返回直播流
      def stream(key)
        Stream.new(key, self, @http_client_v2, @auth, @domain)
      end

      # 创建直播流
      #
      # @param [String] key 直播流名称
      # @raise [QiniuNg::HTTP::ResourceExists] 直播流已经存在
      # @return [Stream] 返回直播流
      def create_stream(key, pili_url: nil, https: nil, **options)
        @http_client_v2.post("/v2/hubs/#{@name}/streams", pili_url || get_pili_url(https),
                             headers: { content_type: 'application/json' },
                             body: Config.default_json_marshaler.call(key: key),
                             **options)
        stream(key)
      end

      # 批量查询直播实时信息
      #
      # @param [Array<String>] stream_keys 提供需要查询的直播流
      # @return [Hash<String, Stream::LiveInfo>] 返回直播流实时信息，Key 为直播流名称，Value 为直播流实时信息。
      #   并非所有在 stream_keys 中的直播流都会返回在结果中，如果该直播流当时没有处于直播状态，则不会返回
      def live_info(*stream_keys, pili_url: nil, https: nil, **options)
        return {} if stream_keys.empty?

        path = "/v2/hubs/#{@name}/livestreams"
        resp_body = @http_client_v2.post(path, pili_url || get_pili_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(items: stream_keys),
                                         **options).body
        resp_body['items'].each_with_object({}) do |item, hash|
          hash[item['key']] = Stream::LiveInfo.new(item)
        end.freeze
      end

      # 列出所有直播流
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   streams = client.hub('<Hub Name>', domain: '<Hub Domain>').streams
      #
      # @param [Boolean] live_only 是否正处于直播状态
      # @param [String] prefix 匹配直播流前缀
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Enumerable] 返回一个{迭代器}[https://ruby-doc.org/core-2.6/Enumerable.html]实例
      def streams(live_only: false, prefix: nil, pili_url: nil, limit: nil, marker: nil, https: nil, **options)
        StreamsIterator.new(self, @http_client_v2, live_only, prefix, limit, marker, pili_url, https, options)
      end

      # @!visibility private
      class StreamsIterator
        include Enumerable

        # @!visibility private
        def initialize(hub, http_client_v2, live_only, prefix, limit, marker, pili_url, https, options)
          @hub = hub
          @http_client_v2 = http_client_v2
          @live_only = live_only
          @prefix = prefix
          @limit = limit
          @marker = marker
          @pili_url = pili_url || get_pili_url(https)
          @got = 0
          @options = options
        end

        # @!visibility private
        def each
          return enumerator unless block_given?

          enumerator.each do |stream|
            yield stream
          end
        end

        private

        def enumerator
          Enumerator.new do |yielder|
            loop do
              params = {}
              params[:liveonly] = 'true' if @live_only
              params[:prefix] = @prefix unless @prefix.nil? || @prefix.empty?
              params[:limit] = @limit unless @limit.nil? || !@limit.positive?
              params[:marker] = @marker unless @marker.nil? || @marker.empty?
              body = @http_client_v2.get("/v2/hubs/#{@hub.name}/streams", @pili_url,
                                         params: params, **@options).body
              break if body['items'].size.zero?

              body['items'].each do |item|
                break unless @limit.nil? || @got < @limit

                yielder << @hub.stream(item['key'])
                @got += 1
              end
              @marker = body['marker']
              break if @marker.nil? || @marker.empty? || (!@limit.nil? && @got >= @limit)
            end
          end
        end

        def get_pili_url(https)
          Common::Zone.pili_url(https)
        end
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} @name=#{@name.inspect}>"
      end

      private

      def get_pili_url(https)
        Common::Zone.pili_url(https)
      end
    end
  end
end
