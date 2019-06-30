# frozen_string_literal: true

module QiniuNg
  module Storage
    # 上传控制器
    class Uploader
      def initialize(bucket, http_client, auth, block_size: Config.default_upload_block_size)
        @form_uploader = FormUploader.new(bucket, http_client, auth)
        @resumable_uploader = ResumableUploader.new(bucket, http_client, auth, block_size: block_size)
      end

      def upload(filepath: nil, stream: nil, key: nil, upload_token: nil, params: {}, meta: {},
                 recorder: Recorder::FileRecorder.new, mime_type: nil, disable_checksum: false,
                 resumable_policy: :auto, https: nil, **options)
        if resumable_policy != :never && File.size(filepath) > Config.upload_threshold || resumable_policy == :always
          if filepath
            @resumable_uploader.sync_upload_file(filepath, key: key, upload_token: upload_token, params: params,
                                                           meta: meta, recorder: recorder, mime_type: mime_type,
                                                           disable_checksum: disable_checksum, https: https, **options)
          elsif stream
            @resumable_uploader.sync_upload_stream(stream, key: key, upload_token: upload_token, params: params,
                                                           meta: meta, recorder: recorder, mime_type: mime_type,
                                                           disable_checksum: disable_checksum, https: https, **options)
          end
        elsif filepath
          @form_uploader.sync_upload_file(filepath, key: key, upload_token: upload_token, params: params, meta: meta,
                                                    mime_type: mime_type, disable_checksum: disable_checksum,
                                                    https: https, **options)
        elsif stream
          @form_uploader.sync_upload_stream(stream, key: key, upload_token: upload_token, params: params,
                                                    meta: meta, recorder: recorder, mime_type: mime_type,
                                                    disable_checksum: disable_checksum, https: https, **options)
        end
      end
    end
  end
end
