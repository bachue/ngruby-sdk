# frozen_string_literal: true

require 'base64'
require 'digest/md5'

module QiniuNg
  module Storage
    # 上传控制器
    class Uploader
      # @!visibility private
      class ResumableUploader < UploaderBase
        # @!visibility private
        def initialize(bucket, http_client, block_size: Config.default_upload_block_size)
          raise ArgumengError, 'block_size must be multiples of 4 MB' unless (block_size % (1 << 22)).zero?

          @bucket = bucket
          @http_client = http_client
          @block_size = block_size.freeze
        end

        # @!visibility private
        def sync_upload_file(filepath, key: nil, upload_token:, params: {}, meta: {}, filename: nil, recorder: nil,
                             mime_type: DEFAULT_MIME, disable_checksum: false, https: nil, **options)
          File.open(filepath, 'rb') do |file|
            upload_recorder = UploadRecorder.new(recorder, bucket: @bucket.name, key: key, file: file)
            sync_upload_stream(file,
                               key: key, upload_token: upload_token, size: file.size,
                               params: params, meta: meta, filename: filename, mime_type: mime_type,
                               upload_recorder: upload_recorder, disable_checksum: disable_checksum,
                               https: https, **options)
          end
        end

        # @!visibility private
        def sync_upload_stream(stream, key: nil, upload_token:, params: {}, meta: {}, filename: nil, recorder: nil,
                               upload_recorder: nil, size: nil, mime_type: DEFAULT_MIME, disable_checksum: false,
                               https: nil, **options)
          list = []
          upload_recorder ||= UploadRecorder.new(recorder, bucket: @bucket.name, key: key)
          record = upload_recorder.load
          upload_id, part_num, uploaded_size = if record&.active?(size)
                                                 if stream.respond_to?(:seek)
                                                   stream.seek(record.uploaded_size, :CUR)
                                                 else
                                                   stream.read(record.uploaded_size)
                                                 end
                                                 list = record.etag_idxes
                                                 [record.upload_id, record.etag_idxes.size, record.uploaded_size]
                                               else
                                                 [init_parts(key, upload_token, https: https, **options), 0, 0]
                                               end
          loop do
            block = stream.read(@block_size)
            break if block.nil?

            part_num += 1
            actual_etag = upload_part(block, key, upload_token, upload_id, part_num,
                                      disable_checksum: disable_checksum, https: https, **options)
            unless disable_checksum
              validate_part_checksum(actual_etag, block)
              block_sha1 = Utils::Etag.sha1(block)
            end
            list << { etag: actual_etag, part_num: part_num, sha1: block_sha1 }
            uploaded_size += @block_size
            upload_recorder.sync(Record.new(upload_id, list, uploaded_size: uploaded_size))
          end
          result = complete_parts(list, key, upload_token, upload_id,
                                  meta: meta, filename: filename, mime_type: mime_type, params: params,
                                  https: https, **options)
          validate_parts_checksum(result.key, result.hash, list) unless disable_checksum
          upload_recorder.del
          result
        end

        private

        def validate_parts_checksum(key, actual, etag_idxes, https: nil, **options)
          return if actual.nil?

          sha1s = etag_idxes.map { |ei| ei[:sha1] }
          return if sha1s.detect(&:nil?) || Utils::Etag.encode_sha1s(sha1s) == actual

          begin
            @bucket.entry(key).delete(https: https, **options) if key
          ensure
            raise ChecksumError
          end
        end

        def validate_part_checksum(actual, block)
          raise ChecksumError unless Utils::Etag.from_data(block) == actual
        end

        def init_parts(key, upload_token, https: nil, **options)
          resp = @http_client.post(
            "/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads", up_urls(https),
            headers: { authorization: "UpToken #{upload_token}" },
            retry_if: ->(s, h, b, e) { need_retry(s, h, b, e, upload_token.policy) },
            idempotent: true,  **options
          )
          resp.body['uploadId']
        end

        def upload_part(data, key, upload_token, upload_id, part_num, disable_checksum: false, https: nil, **options)
          headers = { authorization: "UpToken #{upload_token}", content_type: 'application/octet-stream' }
          headers[:content_md5] = Digest::MD5.hexdigest(data) unless disable_checksum
          resp = @http_client.put(
            "/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}/#{part_num}", up_urls(https),
            headers: headers, body: data,
            retry_if: ->(s, h, b, e) { need_retry(s, h, b, e, upload_token.policy) },
            idempotent: true,  **options
          )
          resp.body['etag']
        end

        def complete_parts(list, key, upload_token, upload_id,
                           meta: {}, filename: nil, mime_type: nil, params: nil, https: nil, **options)
          filename = 'fileName' if filename.nil? || filename.empty?
          headers = { authorization: "UpToken #{upload_token}", content_type: 'text/plain' }
          body = {
            parts: list.map { |hash| { etag: hash[:etag], partNumber: hash[:part_num] } },
            fname: filename, metadata: meta, mimeType: mime_type,
            customVars: params.each_with_object({}) { |(k, v), h| h["x:#{k}"] = v }
          }
          resp = @http_client.post(
            "/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}", up_urls(https),
            headers: headers, body: Config.default_json_marshaler.call(body),
            retry_if: ->(s, h, b, e) { need_retry(s, h, b, e, upload_token.policy) },
            idempotent: true, **options
          )
          Result.new(resp.body)
        end

        def delete_parts(key, upload_token, upload_id, https: nil, **options)
          @http_client.delete(
            "/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}", up_urls(https),
            headers: { authorization: "UpToken #{upload_token}" },
            retry_if: ->(s, h, b, e) { need_retry(s, h, b, e, upload_token.policy) },
            idempotent: true, **options
          )
          nil
        end

        def encode(key)
          key.nil? ? '~' : Base64.urlsafe_encode64(key)
        end

        # 分块上传记录
        class Record
          attr_reader :upload_id, :created_at, :etag_idxes, :uploaded_size
          # @!visibility private
          def initialize(upload_id, etag_idxes, uploaded_size: 0, created_at: Time.now)
            @upload_id = upload_id
            @etag_idxes = etag_idxes || []
            @uploaded_size = uploaded_size
            @created_at = created_at
          end

          # @!visibility private
          def self.from_json(json)
            hash = Config.default_json_unmarshaler.call(json)
            etag_idxes = hash['etag_idxes'].each_with_object([]) do |ei, obj|
              h = { etag: ei['etag'], part_num: ei['part_num'] }
              h[:sha1] = [h['sha1']].pack('H*') unless ei['sha1'].nil? || ei['sha1'].empty?
              obj << h
            end
            new(hash['upload_id'], etag_idxes,
                uploaded_size: hash['uploaded_size'], created_at: Time.at(hash['created_at']))
          end

          # @!visibility private
          def to_json(*args)
            hash = { upload_id: @upload_id, uploaded_size: @uploaded_size, created_at: @created_at.to_i }
            hash[:etag_idxes] = @etag_idxes.each_with_object([]) do |ei, obj|
              sha1 = ei[:sha1].unpack('H*').first unless ei[:sha1].nil? || ei[:sha1].empty?
              obj << { etag: ei[:etag], part_num: ei[:part_num], sha1: sha1 }
            end
            Config.default_json_marshaler.call(hash, *args)
          end

          # @!visibility private
          def active?(file_size)
            ok = @created_at > Time.now - Utils::Duration.new(days: 5).to_i &&
                 !@upload_id.nil? && !@upload_id.empty? &&
                 !@etag_idxes.nil? && !@etag_idxes.empty? &&
                 @uploaded_size.positive? && !file_size.nil? && @uploaded_size <= file_size
            @etag_idxes.each_with_index.detect { |ei, i| ei[:part_num] != i + 1 }.nil? if ok
          end
        end

        # 分块上传记录仪
        class UploadRecorder
          # @!visibility private
          def initialize(recorder, bucket: nil, key: nil, file: nil)
            if recorder
              @recorder = recorder
              @record_key = recorder.class.recorder_key_for_file(bucket: bucket, key: key, file: file)
            else
              @recorder = nil
              @record_key = nil
            end
          end

          # @!visibility private
          def load
            Record.from_json(@recorder&.get(@record_key)) if @record_key
          rescue StandardError
            nil
          end

          # @!visibility private
          def del
            @recorder&.del(@record_key) if @record_key
          end

          # @!visibility private
          def sync(record)
            @recorder&.set(@record_key, Config.default_json_marshaler.call(record)) if @record_key
          end
        end
      end
    end
  end
end
