# frozen_string_literal: true

require 'base64'
require 'digest/md5'

module QiniuNg
  module Storage
    # 上传控制器
    class Uploader
      # 分块上传
      class ResumableUploader < UploaderBase
        def initialize(bucket, http_client, auth, block_size: Config.default_upload_block_size)
          raise ArgumengError, 'block_size must be multiples of 4 MB' unless (block_size % (1 << 22)).zero?

          @bucket = bucket
          @http_client = http_client
          @auth = auth
          @block_size = block_size.freeze
        end

        def sync_upload_file(filepath,
                             key: nil, upload_token: nil, params: {}, meta: {}, recorder: nil,
                             mime_type: DEFAULT_MIME, disable_checksum: false, https: nil, **options)
          File.open(filepath, 'rb') do |file|
            upload_recorder = UploadRecorder.new(recorder, bucket: @bucket.name, key: key, file: file)
            sync_upload_stream(file,
                               key: key, upload_token: upload_token, size: file.size,
                               params: params, meta: meta, mime_type: mime_type,
                               upload_recorder: upload_recorder, disable_checksum: disable_checksum,
                               https: https, **options)
          end
        end

        def sync_upload_stream(stream,
                               key: nil, upload_token: nil, params: {}, meta: {}, recorder: nil, upload_recorder: nil,
                               size: nil, mime_type: DEFAULT_MIME, disable_checksum: false, https: nil, **options)
          unuse(mime_type, params)
          key ||= extract_key_from_upload_token(upload_token) or raise ArgumentError, 'missing keyword: key'

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
          result = complete_parts(list, key, upload_token, upload_id, meta: meta, https: https, **options)
          validate_parts_checksum(result.key, result.hash, list) unless disable_checksum
          upload_recorder.del
          result
        end

        private

        def validate_parts_checksum(key, actual, etag_idxes, https: nil, **options)
          sha1s = etag_idxes.map { |ei| ei[:sha1] }
          return if sha1s.detect(&:nil?) || Utils::Etag.encode_sha1s(sha1s) == actual

          @bucket.entry(key).delete(https: https, **options)
          raise ChecksumError
        end

        def validate_part_checksum(actual, block)
          raise ChecksumError unless Utils::Etag.from_data(block) == actual
        end

        def init_parts(key, upload_token, https: nil, **options)
          resp = @http_client.post(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads",
            backup_urls: up_backup_urls(https), headers: { authorization: "UpToken #{upload_token}" }, **options
          )
          resp.body['uploadId']
        end

        def upload_part(data, key, upload_token, upload_id, part_num, disable_checksum: false, https: nil, **options)
          headers = { authorization: "UpToken #{upload_token}", content_type: 'application/octet-stream' }
          headers[:content_md5] = Digest::MD5.hexdigest(data) unless disable_checksum
          resp = @http_client.put(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}/#{part_num}",
            backup_urls: up_backup_urls(https), headers: headers, body: data, **options
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
            backup_urls: up_backup_urls(https), headers: headers, body: body.to_json, **options
          )
          Result.new(resp.body['hash'], resp.body['key'])
        end

        def delete_parts(key, upload_token, upload_id, https: nil, **options)
          @http_client.delete(
            "#{up_url(https)}/buckets/#{@bucket.name}/objects/#{encode(key)}/uploads/#{upload_id}",
            backup_urls: up_backup_urls(https), headers: { authorization: "UpToken #{upload_token}" }, **options
          )
          nil
        end

        def encode(key)
          Base64.urlsafe_encode64(key)
        end

        def unuse(*_args)
          nil
        end

        # 分块上传记录
        class Record
          attr_reader :upload_id, :created_at, :etag_idxes, :uploaded_size
          def initialize(upload_id, etag_idxes, uploaded_size: 0, created_at: Time.now)
            @upload_id = upload_id
            @etag_idxes = etag_idxes || []
            @uploaded_size = uploaded_size
            @created_at = created_at
          end

          def self.from_json(json)
            require 'json' unless defined?(JSON)
            hash = JSON.parse(json)
            etag_idxes = hash['etag_idxes'].each_with_object([]) do |ei, obj|
              h = { etag: ei['etag'], part_num: ei['part_num'] }
              h[:sha1] = [h['sha1']].pack('H*') unless ei['sha1'].nil? || ei['sha1'].empty?
              obj << h
            end
            new(hash['upload_id'], etag_idxes,
                uploaded_size: hash['uploaded_size'], created_at: Time.at(hash['created_at']))
          end

          def to_json(*args)
            hash = { upload_id: @upload_id, uploaded_size: @uploaded_size, created_at: @created_at.to_i }
            hash[:etag_idxes] = @etag_idxes.each_with_object([]) do |ei, obj|
              sha1 = ei[:sha1].unpack1('H*') unless ei[:sha1].nil? || ei[:sha1].empty?
              obj << { etag: ei[:etag], part_num: ei[:part_num], sha1: sha1 }
            end
            require 'json' unless hash.respond_to?(:to_json)
            hash.to_json(*args)
          end

          def active?(file_size)
            ok = @created_at > Time.now - Duration.new(days: 5).to_i &&
                 !@upload_id.nil? && !@upload_id.empty? &&
                 !@etag_idxes.nil? && !@etag_idxes.empty? &&
                 @uploaded_size.positive? && !file_size.nil? && @uploaded_size <= file_size
            @etag_idxes.each_with_index.detect { |ei, i| ei[:part_num] != i + 1 }.nil? if ok
          end
        end

        # 分块上传记录仪
        class UploadRecorder
          def initialize(recorder, bucket: nil, key: nil, file: nil)
            if recorder
              @recorder = recorder
              @record_key = recorder.class.recorder_key_for_file(bucket: bucket, key: key, file: file)
            else
              @recorder = nil
              @record_key = nil
            end
          end

          def load
            Record.from_json(@recorder&.get(@record_key)) if @record_key
          rescue StandardError
            nil
          end

          def del
            @recorder&.del(@record_key) if @record_key
          end

          def sync(record)
            @recorder&.set(@record_key, record.to_json) if @record_key
          end
        end
      end
    end
  end
end
