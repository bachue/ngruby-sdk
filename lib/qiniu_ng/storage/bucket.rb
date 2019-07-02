# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛空间
    class Bucket
      def initialize(bucket_name, zone, http_client_v1, http_client_v2, auth)
        @bucket_name = bucket_name.freeze
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
        @zone = zone
      end

      def name
        @bucket_name
      end

      def zone
        @zone ||= begin
          Common::Zone.auto.query(access_key: @auth.access_key, bucket: @bucket_name)
        end
      end
      attr_writer :zone

      def drop(rs_zone: nil, https: nil, **options)
        @http_client_v1.post("#{get_rs_url(rs_zone, https)}/drop/#{@bucket_name}", **options)
        nil
      end
      alias delete drop

      def domains(api_zone: nil, https: nil, **options)
        url = "#{get_api_url(api_zone, https)}/v6/domain/list"
        @http_client_v1.get(url, params: { tbl: @bucket_name }, **options).body
      end

      def set_image(source_url, uc_url: nil, source_host: nil, https: nil, **options)
        encoded_url = Base64.urlsafe_encode64(source_url)
        url = "#{uc_url || get_uc_url(https)}/image/#{@bucket_name}/from/#{encoded_url}"
        url += "/host/#{Base64.urlsafe_encode64(source_host)}" unless source_host.nil? || source_host.empty?
        @http_client_v1.post(url, **options)
        nil
      end

      def unset_image(uc_url: nil, https: nil, **options)
        @http_client_v1.post("#{uc_url || get_uc_url(https)}/unimage/#{@bucket_name}", **options)
        nil
      end

      def public!(uc_url: nil, https: nil, **options)
        update_acl(private_access: false, uc_url: uc_url, https: https, **options)
      end

      def private!(uc_url: nil, https: nil, **options)
        update_acl(private_access: true, uc_url: uc_url, https: https, **options)
      end

      def private?(uc_url: nil, https: nil, **options)
        info(uc_url: uc_url, https: https, **options)['private'] == 1
      end

      ImageInfo = Struct.new(:source_url, :source_host)

      def image(uc_url: nil, https: nil, **options)
        result = info(uc_url: uc_url, https: https, **options)
        ImageInfo.new(result['source'], result['host']) if result['source']
      end

      def enable_index_page(uc_url: nil, https: nil, **options)
        set_index_page(true, uc_url: uc_url, https: https, **options)
      end

      def disable_index_page(uc_url: nil, https: nil, **options)
        set_index_page(false, uc_url: uc_url, https: https, **options)
      end

      def has_index_page?(uc_url: nil, https: nil, **options)
        info(uc_url: uc_url, https: https, **options)['no_index_page'].zero?
      end

      def entry(key)
        Entry.new(self, key, @http_client_v1, @http_client_v2, @auth)
      end

      def uploader(block_size: Config.default_upload_block_size)
        Uploader.new(self, @http_client_v1, @auth, block_size: block_size)
      end

      def upload_token(key: nil, key_prefix: nil)
        return upload_token_for_key(key) unless key.nil?
        return upload_token_for_key_prefix(key_prefix) unless key_prefix.nil?

        policy = Model::UploadPolicy.new(bucket: @bucket_name)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      def upload_token_for_key(key)
        policy = Model::UploadPolicy.new(bucket: @bucket_name, key: key)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      def upload_token_for_key_prefix(key_prefix)
        policy = Model::UploadPolicy.new(bucket: @bucket_name, key_prefix: key_prefix)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      def batch
        BatchOperations.new(self, @http_client_v1, @http_client_v2, @auth)
      end

      private

      def set_index_page(enabled, uc_url: nil, https: nil, **options)
        no_index_page = Utils::Bool.to_int(!enabled)
        params = { bucket: @bucket_name, noIndexPage: no_index_page }
        @http_client_v1.post("#{uc_url || get_uc_url(https)}/noIndexPage", params: params, **options)
        nil
      end

      def update_acl(private_access:, uc_url: nil, https: nil, **options)
        private_access = Utils::Bool.to_int(private_access)
        params = { bucket: @bucket_name, private: private_access }
        @http_client_v1.post("#{uc_url || get_uc_url(https)}/private", params: params, **options)
        nil
      end

      def info(uc_url: nil, https: nil, **options)
        @http_client_v1.get("#{uc_url || get_uc_url(https)}/v2/bucketInfo",
                            params: { bucket: @bucket_name },
                            **options).body
      end

      def get_api_url(api_zone, https)
        https = Config.use_https if https.nil?
        api_zone ||= Common::Zone.huadong
        api_zone.api(https)
      end

      def get_rs_url(rs_zone, https)
        https = Config.use_https if https.nil?
        rs_zone ||= Common::Zone.huadong
        rs_zone.rs(https)
      end

      def get_uc_url(https)
        Utils::Bool.to_bool(https) ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
      end
    end
  end
end
