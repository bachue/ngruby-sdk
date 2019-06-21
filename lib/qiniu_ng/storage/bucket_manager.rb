# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛 SDK 存储管理
    class BucketManager
      def initialize(http_client)
        @http_client = http_client
      end

      def bucket_names(https: false)
        @http_client.get("#{Common::Zone.huadong.rs(https)}/buckets").body
      end
    end
  end
end
