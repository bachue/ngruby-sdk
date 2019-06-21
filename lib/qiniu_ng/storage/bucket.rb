# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛空间
    class Bucket
      def initialize(bucket_name, http_client:)
        @bucket_name = bucket_name
        @http_client = http_client
      end

      def name
        @bucket_name
      end

      def domains(https: nil, **options)
        @http_client.get("#{api_url(https)}/v6/domain/list", params: { tbl: @bucket_name }, **options).body
      end

      private

      def api_url(https)
        https = Config.use_https if https.nil?
        Common::Zone.huadong.api(https)
      end
    end
  end
end
