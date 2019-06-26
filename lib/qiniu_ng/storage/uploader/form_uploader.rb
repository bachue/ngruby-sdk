# frozen_string_literal: true

require 'digest/crc32'

module QiniuNg
  module Storage
    # 模块上传
    module Uploader
      # 表单上传
      class FormUploader
        Result = Struct.new(:hash, :key)

        def initialize(bucket, http_client, auth)
          @bucket = bucket
          @http_client = http_client
          @auth = auth
        end

        def sync_upload_file(filepath, key: nil, upload_token: nil, params: {}, meta: {},
                             mime_type: nil, disable_crc32: false, https: nil, **options)
          crc32 = Digest::CRC32.file(filepath).digest.unpack1('N*') unless disable_crc32
          resp = @http_client.post("#{up_url(https)}/",
                                   headers: { content_type: 'multipart/form-data' },
                                   body: build_request_body(key: key,
                                                            upload_token: upload_token,
                                                            upload_io: Faraday::UploadIO.new(filepath, mime_type),
                                                            params: params, meta: meta, crc32: crc32),
                                   **options)
          Result.new(resp.body['hash'], resp.body['key'])
        end

        def sync_upload_stream(stream, key: nil, upload_token: nil, params: {}, meta: {},
                               mime_type: nil, crc32: nil, https: nil, **options)
          resp = @http_client.post("#{up_url(https)}/",
                                   headers: { content_type: 'multipart/form-data' },
                                   body: build_request_body(key: key,
                                                            upload_token: upload_token,
                                                            upload_io: Faraday::UploadIO.new(stream, mime_type),
                                                            params: params, meta: meta, crc32: crc32),
                                   **options)
          Result.new(resp.body['hash'], resp.body['key'])
        end

        private

        def build_request_body(key:, upload_token:, upload_io:, params:, meta:, crc32:)
          if key.nil?
            upload_token = UploadToken.from_token(upload_token) if upload_token.is_a?(String)
            upload_policy = upload_token.policy
            raise ArgumentError, 'missing keyword: key' if upload_policy.save_key.nil? && upload_policy.prefixal_scope?

            key = upload_policy.save_key || upload_policy.key
          end
          body = { token: upload_token.to_s }
          body[:key] = key
          body[:file] = upload_io
          body[:crc32] = crc32 unless crc32.nil?
          body[:fileName] = upload_io.original_filename
          body[:fileName] = 'fileName' if body[:fileName].nil? || body[:fileName].empty?
          params.each do |k, v|
            body[:"x:#{k}"] = v
          end
          meta.each do |k, v|
            body[:"x-qn-meta-#{k}"] = v
          end
          body
        end

        def up_url(https)
          https = Config.use_https if https.nil?
          @bucket.zone.up(https)
        end
      end
    end
  end
end
