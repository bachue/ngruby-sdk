# frozen_string_literal: true

require 'digest/crc32'

module QiniuNg
  module Storage
    # 上传控制器
    class Uploader
      # 表单上传
      class FormUploader < UploaderBase
        def sync_upload_file(filepath, key: nil, upload_token: nil, params: {}, meta: {},
                             mime_type: DEFAULT_MIME, disable_checksum: false, https: nil, **options)
          crc32 = crc32_of_file(filepath) unless disable_checksum
          resp = @http_client.post("#{up_url(https)}/",
                                   backup_urls: up_backup_urls(https),
                                   headers: { content_type: 'multipart/form-data' },
                                   body: build_request_body(key: key,
                                                            upload_token: upload_token,
                                                            upload_io: Faraday::UploadIO.new(filepath, mime_type),
                                                            params: params, meta: meta, crc32: crc32),
                                   **options)
          unless disable_checksum
            validate_etag(resp.body['key'], resp.body['hash'], etag_of_file(filepath), https: https, **options)
          end
          Result.new(resp.body['hash'], resp.body['key'])
        end

        def sync_upload_stream(stream, key: nil, upload_token: nil, params: {}, meta: {}, mime_type: DEFAULT_MIME,
                               disable_checksum: false, crc32: nil, etag: nil, https: nil, **options)
          if disable_checksum
            crc32 = nil
            etag = nil
          else
            crc32 ||= guess_crc32_of_stream(stream)
            etag ||= guess_etag_of_stream(stream) || begin
              String.new.tap { |str| stream = Utils::Etag::Reader.new(stream, str) }
            end
          end
          resp = @http_client.post("#{up_url(https)}/",
                                   backup_urls: up_backup_urls(https),
                                   headers: { content_type: 'multipart/form-data' },
                                   body: build_request_body(key: key,
                                                            upload_token: upload_token,
                                                            upload_io: Faraday::UploadIO.new(stream, mime_type),
                                                            params: params, meta: meta, crc32: crc32),
                                   **options)
          validate_etag(resp.body['key'], resp.body['hash'], etag, https: https, **options) unless etag.nil?
          Result.new(resp.body['hash'], resp.body['key'])
        end

        private

        def validate_etag(key, actual, expected, https: nil, **options)
          return if expected == actual

          @bucket.entry(key).delete(https: https, **options)
          raise ChecksumError
        end

        def guess_crc32_of_stream(stream)
          if stream.respond_to?(:path)
            crc32_of_file(stream.path)
          elsif stream.respond_to?(:string)
            crc32_of_string(stream.string)
          end
        end

        def guess_etag_of_stream(stream)
          if stream.respond_to?(:path)
            etag_of_file(stream.path)
          elsif stream.respond_to?(:string)
            etag_of_string(stream.string)
          end
        end

        def crc32_of_file(filepath)
          Digest::CRC32.file(filepath).digest.unpack1('N*')
        end

        def crc32_of_string(string)
          Digest::CRC32.digest(string).unpack1('N*')
        end

        def etag_of_file(filepath)
          Utils::Etag.from_file_path(filepath)
        end

        def etag_of_string(string)
          Utils::Etag.from_data(string)
        end

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
