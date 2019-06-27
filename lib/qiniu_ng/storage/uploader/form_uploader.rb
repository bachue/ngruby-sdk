# frozen_string_literal: true

require 'digest/crc32'

module QiniuNg
  module Storage
    # 上传模块
    module Uploader
      # 表单上传
      class FormUploader < UploaderBase
        def sync_upload_file(filepath, key: nil, upload_token: nil, params: {}, meta: {},
                             mime_type: nil, disable_crc32: false, https: nil, **options)
          crc32 = Digest::CRC32.file(filepath).digest.unpack1('N*') unless disable_crc32
          resp = @http_client.post("#{up_url(https)}/",
                                   backup_urls: up_backup_urls(https),
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
                                   backup_urls: up_backup_urls(https),
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
          body = { token: upload_token.to_s }
          body[:key] = key || extract_key_from_upload_token(upload_token) or raise ArgumentError, 'missing keyword: key'
          body[:file] = upload_io
          body[:crc32] = crc32 unless crc32.nil?
          body[:fileName] = upload_io.original_filename
          body[:fileName] = 'fileName' if body[:fileName].nil? || body[:fileName].empty?
          params.each { |k, v| body[:"x:#{k}"] = v }
          meta.each { |k, v| body[:"x-qn-meta-#{k}"] = v }
          body
        end
      end
    end
  end
end
