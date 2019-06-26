# frozen_string_literal: true

require 'base64'
require 'forwardable'

module QiniuNg
  module Storage
    # 七牛空间中的文件项
    class Entry
      extend Forwardable
      attr_reader :bucket, :key

      def initialize(bucket, key, http_client, auth)
        @bucket = bucket
        @key = key
        @entry = Model::Entry.new(bucket: bucket.name, key: key)
        @http_client = http_client
        @auth = auth
      end
      def_delegators :@entry, :to_s, :encode

      def stat(https: nil, **options)
        op = Op::Stat.new(self)
        op.parse(@http_client.get("#{rs_url(https)}#{op}", **options).body)
      end

      def disable!(https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeStatus.new(self, disabled: true)}", **options)
        self
      end

      def enable!(https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeStatus.new(self, disabled: false)}", **options)
        self
      end

      def set_lifetime(days:, https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::SetLifetime.new(self, days: days)}", **options)
        self
      end

      def normal_storage!(https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeType.new(self, type: Model::StorageType.normal)}", **options)
        self
      end

      def infrequent_storage!(https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeType.new(self, type: Model::StorageType.infrequent)}", **options)
        self
      end

      def change_mime_type(mime_type, https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeMIMEType.new(self, mime_type: mime_type)}", **options)
        self
      end

      def change_meta(meta, https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::ChangeMeta.new(self, meta: meta)}", **options)
        self
      end

      def rename_to(key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: @bucket.name, key: key, force: force)
        @http_client.post("#{rs_url(https)}#{op}", **options)
        self
      end

      def move_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: bucket_name, key: key, force: force)
        @http_client.post("#{rs_url(https)}#{op}", **options)
        self
      end

      def copy_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Copy.new(self, bucket: bucket_name, key: key, force: force)
        @http_client.post("#{rs_url(https)}#{op}", **options)
        self
      end

      def delete(https: nil, **options)
        @http_client.post("#{rs_url(https)}#{Op::Delete.new(self)}", **options)
        self
      end

      def download_url(domain: nil, https: nil, **options)
        domain = @bucket.domains(https: https, **options).first if domain.nil? || domain.empty?
        DownloadURL.new(domain, @key, @auth, https: https) if domain
      end

      def upload_token
        policy = Model::UploadPolicy.new(bucket: @bucket.name, key: @key)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      private

      def rs_url(https)
        https = Config.use_https if https.nil?
        @bucket.zone.rs(https)
      end
    end
  end
end
