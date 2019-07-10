# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    # 七牛空间管理
    class BucketManager
      def initialize(http_client_v1, http_client_v2, auth)
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
      end

      def bucket_names(rs_zone: nil, https: nil, **options)
        @http_client_v1.get('/buckets', rs_url(rs_zone, https), **options).body
      end

      def create_bucket(bucket_name, zone: :z0, rs_zone: nil, https: nil, **options)
        region = zone.is_a?(Common::Zone) ? zone.region || :z0 : zone
        encoded_bucket_name = Base64.urlsafe_encode64(bucket_name)
        @http_client_v1.post("/mkbucketv2/#{encoded_bucket_name}/region/#{region}", rs_url(rs_zone, https), **options)
        bucket(bucket_name)
      end

      def bucket(bucket_name, zone: nil, domains: nil)
        Bucket.new(bucket_name, zone, @http_client_v1, @http_client_v2, @auth, domains)
      end

      private

      def rs_url(rs_zone, https)
        https = Config.use_https if https.nil?
        rs_zone ||= Common::Zone.huadong
        rs_zone.rs_url(https)
      end
    end
  end
end
