# frozen_string_literal: true

require 'base64'
require 'digest/md5'

module QiniuNg
  module Storage
    # 上传模块
    module Uploader
      # 分块上传
      class ResumableUploader < UploaderBase
        def initialize(bucket, http_client, auth, recorder: nil, block_size: 1 << 22)
          raise ArgumengError, 'block_size must be multiples of 4 MB' unless (block_size % (1 << 22)).zero?

          @bucket = bucket
          @http_client = http_client
          @auth = auth
          @recorder = recorder
          @block_size = block_size.freeze
        end

        def sync_upload_file(filepath,
                             key: nil, upload_token: nil, params: {}, meta: {},
                             mime_type: nil, disable_md5: false, https: nil, **options)
          File.open(filepath, 'rb') do |stream|
            sync_upload_stream(stream,
                               key: key, upload_token: upload_token, params: params, meta: meta,
                               mime_type: mime_type, disable_md5: disable_md5, https: https, **options)
          end
        end

        # rubocop:disable Lint/UnusedMethodArgument
        def sync_upload_stream(stream,
                               key: nil, upload_token: nil, params: {}, meta: {},
                               mime_type: nil, disable_md5: false, https: nil, **options)
          # rubocop:enable Lint/UnusedMethodArgument
          key ||= extract_key_from_upload_token(upload_token) or raise ArgumentError, 'missing keyword: key'

          list = []
          upload_id = init_parts(key, upload_token, https: https, **options)
          part_num = 0
          begin
            loop do
              block = stream.read(@block_size)
              break if block.nil?

              part_num += 1
              list << {
                etag: upload_part(block, key, upload_token, upload_id, part_num,
                                  disable_md5: disable_md5, https: https, **options),
                part_num: part_num
              }
            end
          rescue StandardException
            delete_parts(key, upload_token, upload_id, https: https, **options) unless upload_id.nil?
            raise
          end
          complete_parts(list, key, upload_token, upload_id, meta: meta, https: https, **options)
        end

        private

        def init_parts(key, upload_token, https: nil, **options)
          resp = @http_client.post(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads",
            headers: { authorization: "UpToken #{upload_token}" }, **options
          )
          resp.body['uploadId']
        end

        def upload_part(data, key, upload_token, upload_id, part_num, disable_md5: false, https: nil, **options)
          headers = { authorization: "UpToken #{upload_token}", content_type: 'application/octet-stream' }
          headers[:content_md5] = Digest::MD5.hexdigest(data) unless disable_md5
          resp = @http_client.put(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}/#{part_num}",
            headers: headers, body: data, **options
          )
          resp.body['etag']
        end

        def complete_parts(list, key, upload_token, upload_id, meta: {}, https: nil, **options)
          headers = { authorization: "UpToken #{upload_token}", content_type: 'text/plain' }
          meta.each { |k, v| headers[:"x-qn-meta-#{k}"] = v }
          body = { parts: list.map { |hash| { Etag: hash[:etag], PartNumber: hash[:part_num] } } }
          require 'json' unless body.respond_to?(:json)

          resp = @http_client.post(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}",
            headers: headers, body: body.to_json, **options
          )
          Result.new(resp.body['hash'], resp.body['key'])
        end

        def delete_parts(key, upload_token, upload_id, https: nil, **options)
          @http_client.delete(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}",
            headers: { authorization: "UpToken #{upload_token}" }, **options
          )
          nil
        end

        def encode(key)
          Base64.urlsafe_encode64(key)
        end
      end
    end
  end
end
