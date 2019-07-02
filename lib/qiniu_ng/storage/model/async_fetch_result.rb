# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 异步抓取任务标识符
      class AsyncFetchResult
        def initialize(bucket, http_client_v2, id)
          @bucket = bucket
          @http_client_v2 = http_client_v2
          @id = id
        end

        def done?(https: nil, **options)
          resp_body = @http_client_v2.get("#{api_url(https)}/sisyphus/fetch", params: { id: @id }, **options).body
          resp_body['wait'].negative?
        end

        private

        def api_url(https)
          https = Config.use_https if https.nil?
          @bucket.zone.api(https)
        end
      end
    end
  end
end
