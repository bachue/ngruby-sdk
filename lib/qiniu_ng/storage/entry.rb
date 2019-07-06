# frozen_string_literal: true

require 'base64'
require 'forwardable'

module QiniuNg
  module Storage
    # 七牛空间中的文件项
    class Entry
      extend Forwardable
      attr_reader :bucket, :key

      def initialize(bucket, key, http_client_v1, http_client_v2, auth)
        @bucket = bucket
        @key = key.freeze
        @entry = Model::Entry.new(bucket: bucket.name, key: key)
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
      end
      def_delegators :@entry, :to_s, :encode

      def stat(https: nil, **options)
        op = Op::Stat.new(self)
        op.parse(@http_client_v1.get(op, rs_url(https), **options).body)
      end

      def disable!(https: nil, **options)
        @http_client_v1.post(Op::ChangeStatus.new(self, disabled: true), rs_url(https), **options)
        self
      end

      def enable!(https: nil, **options)
        @http_client_v1.post(Op::ChangeStatus.new(self, disabled: false), rs_url(https), **options)
        self
      end

      def set_lifetime(days:, https: nil, **options)
        @http_client_v1.post(Op::SetLifetime.new(self, days: days), rs_url(https), **options)
        self
      end

      def normal_storage!(https: nil, **options)
        @http_client_v1.post(Op::ChangeType.new(self, type: Model::StorageType.normal), rs_url(https), **options)
        self
      end

      def infrequent_storage!(https: nil, **options)
        op = Op::ChangeType.new(self, type: Model::StorageType.infrequent)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      def change_mime_type(mime_type, https: nil, **options)
        @http_client_v1.post(Op::ChangeMIMEType.new(self, mime_type: mime_type), rs_url(https), **options)
        self
      end

      def change_meta(meta, https: nil, **options)
        @http_client_v1.post(Op::ChangeMeta.new(self, meta: meta), rs_url(https), **options)
        self
      end

      def rename_to(key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: @bucket.name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      def move_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: bucket_name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      def copy_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Copy.new(self, bucket: bucket_name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      def delete(https: nil, **options)
        @http_client_v1.post(Op::Delete.new(self), rs_url(https), **options)
        self
      end

      def prefetch(https: nil, **options)
        @http_client_v1.post("/prefetch/#{encode}", io_urls(https), **options)
        self
      end

      def fetch_from(url, async: false, https: nil, **options)
        return async_fetch_from(url, https: https, **options) if async

        encoded_url = Base64.urlsafe_encode64(url)
        body = @http_client_v1.post("/fetch/#{encoded_url}/to/#{encode}", io_urls(https), **options).body
        Model::FetchedEntry.new(self, hash: body['hash'], mime_type: body['mimeType'], file_size: body['fsize'])
      end

      def async_fetch_from(url, md5: nil, https: nil, callback_url: nil, callback_host: nil,
                           callback_body: nil, callback_body_type: nil, **options)
        req_body = {
          url: url, bucket: @bucket.name, key: @key, md5: md5, callbackurl: callback_url,
          callbackhost: callback_host, callbackbody: callback_body, callbackbodytype: callback_body_type
        }.reject { |_, v| v.nil? }
        resp_body = @http_client_v2.post('/sisyphus/fetch', api_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(req_body),
                                         **options).body
        Model::AsyncFetchResult.new(@bucket, @http_client_v2, resp_body['id'])
      end

      def try_delete(https: nil, **options)
        delete(https: https, **options)
      rescue HTTP::ResourceNotFound
        # do nothing
        self
      end

      def download_url(domain: nil, https: nil, **options)
        domain = @bucket.domains(https: https, **options).last if domain.nil? || domain.empty?
        PublicURL.new(domain, @key, @auth, https: https) if domain
      end

      def upload_token
        policy = Model::UploadPolicy.new(bucket: @bucket.name, key: @key)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      private

      def rs_url(https)
        https = Config.use_https if https.nil?
        @bucket.zone.rs_url(https)
      end

      def api_url(https)
        https = Config.use_https if https.nil?
        @bucket.zone.api_url(https)
      end

      def io_urls(https)
        https = Config.use_https if https.nil?
        @bucket.zone.io_urls(https).dup
      end
    end
  end
end
