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

      def set_image(source_url, source_host: nil, https: nil, **options)
        encoded_url = Base64.urlsafe_encode64(source_url)
        url = "#{uc_url(https)}/image/#{@bucket_name}/from/#{encoded_url}"
        url += "/host/#{Base64.urlsafe_encode64(source_host)}" unless source_host.nil? || source_host.empty?
        @http_client.post(url, **options)
        nil
      end

      def unset_image(https: nil, **options)
        @http_client.post("#{uc_url(https)}/unimage/#{@bucket_name}", **options)
        nil
      end

      private

      def api_url(https)
        https = Config.use_https if https.nil?
        Common::Zone.huadong.api(https)
      end

      def uc_url(https)
        https ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
      end
    end
  end
end
