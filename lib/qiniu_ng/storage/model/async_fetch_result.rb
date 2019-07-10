# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 异步抓取任务标识符
      # @!attribute [r] id
      #   @return [String] 异步抓取任务 ID
      class AsyncFetchResult
        # @!visibility private
        def initialize(bucket, http_client_v2, id)
          @bucket = bucket
          @http_client_v2 = http_client_v2
          @id = id
        end
        attr_reader :id

        # 异步抓取任务是否已经完成
        #
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [Boolean] 异步抓取任务是否已经完成
        def done?(https: nil, **options)
          queue_length(https: https, **options).negative?
        end

        # 异步抓取任务队列长度
        #
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [Integer] 异步抓取任务队列长度
        def queue_length(https: nil, **options)
          @http_client_v2.get('/sisyphus/fetch', api_url(https), params: { id: @id }, **options).body['wait']
        end

        private

        def api_url(https)
          https = Config.use_https if https.nil?
          @bucket.zone.api_url(https)
        end
      end
    end
  end
end
