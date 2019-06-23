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

      def drop(https: nil, **options)
        @http_client.post("#{rs_url(https)}/drop/#{@bucket_name}", **options)
        nil
      end
      alias delete drop

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

      def public!(https: nil, **options)
        update_acl(private_access: false, https: https, **options)
      end

      def private!(https: nil, **options)
        update_acl(private_access: true, https: https, **options)
      end

      def private?(https: nil, **options)
        info(https: https, **options)['private'] == 1
      end

      ImageInfo = Struct.new(:source_url, :source_host)

      def image(https: nil, **options)
        result = info(https: https, **options)
        ImageInfo.new(result['source'], result['host']) if result['source']
      end

      def enable_index_page(https: nil, **options)
        set_index_page(true, https: https, **options)
      end

      def disable_index_page(https: nil, **options)
        set_index_page(false, https: https, **options)
      end

      def has_index_page?(https: nil, **options)
        info(https: https, **options)['no_index_page'].zero?
      end

      private

      def set_index_page(enabled, https: nil, **options)
        no_index_page = enabled ? 0 : 1
        params = { bucket: @bucket_name, noIndexPage: no_index_page }
        @http_client.post("#{uc_url(https)}/noIndexPage", params: params, **options)
        nil
      end

      def update_acl(private_access:, https: nil, **options)
        private_access = private_access ? 1 : 0
        params = { bucket: @bucket_name, private: private_access }
        @http_client.post("#{uc_url(https)}/private", params: params, **options)
        nil
      end

      def info(https: nil, **options)
        @http_client.get("#{uc_url(https)}/v2/bucketInfo", params: { bucket: @bucket_name }, **options).body
      end

      def api_url(https)
        https = Config.use_https if https.nil?
        Common::Zone.huadong.api(https)
      end

      def rs_url(https)
        https = Config.use_https if https.nil?
        Common::Zone.huadong.rs(https)
      end

      def uc_url(https)
        https ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
      end
    end
  end
end
