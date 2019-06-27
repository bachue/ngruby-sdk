# frozen_string_literal: true

module QiniuNg
  module Storage
    # 上传模块
    module Uploader
      Result = Struct.new(:hash, :key)
      # 上传父类
      class UploaderBase
        def initialize(bucket, http_client, auth)
          if self.class.name == UploaderBase.name
            raise NoMethodError, "undefined method `new` for #{UploaderBase.name}:Class"
          end

          @bucket = bucket
          @http_client = http_client
          @auth = auth
        end

        private

        def extract_key_from_upload_token(upload_token)
          upload_token = UploadToken.from_token(upload_token) if upload_token.is_a?(String)
          upload_policy = upload_token.policy
          raise ArgumentError, 'missing keyword: key' if upload_policy.save_key.nil? && upload_policy.prefixal_scope?

          upload_policy.save_key || upload_policy.key
        end

        def up_url(https)
          https = Config.use_https if https.nil?
          @bucket.zone.up(https)
        end

        def up_backup_urls(https)
          https = Config.use_https if https.nil?
          [@bucket.zone.up_backup(https), @bucket.zone.up_ip(https)].compact
        end
      end
    end
  end
end
