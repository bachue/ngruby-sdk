# frozen_string_literal: true

module QiniuNg
  module Storage
    # 上传控制器
    class Uploader
      attr_accessor :block_size
      # @!visibility private
      def initialize(bucket, http_client, block_size: Config.default_upload_block_size)
        @block_size = block_size
        @form_uploader = FormUploader.new(bucket, http_client)
        @resumable_uploader = ResumableUploader.new(bucket, http_client, block_size: block_size)
      end

      # 上传文件或数据流
      #
      # @example
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.upload(filepath: '/path/to/file', upload_token: bucket.upload_token)
      #
      # @param [Pathname] filepath 上传文件的路径，与 stream 参数不要同时使用
      # @param [#read] stream 上传数据流，与 filepath 参数不要同时使用
      # @param [String] key 上传到存储空间后的文件名，将由七牛云自动决定文件名。
      # @param [Hash] params 指定自定义变量，注意，SDK 将为每个变量名自动增加 "x:" 前缀。
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1235/vars]
      # @param [Hash] meta 指定文件的 HTTP Header 信息，注意，SDK 将为每个 HTTP Header Key 自动增加 "x-qn-meta-" 前缀
      # @param [QiniuNg::Storage::Recorder] recorder 上传进度记录器，将在分片上传时，保存上传进度，以便于在上传失败后断点续传
      #   默认将使用临时文件保存上传进度，文件所在目录定义在 QiniuNg::Config.default_file_recorder_path 中
      # @param [String] mime_type 指定文件的 MIME 类型
      # @param [Boolean] disable_checksum 是否禁用上传校验（不推荐禁用）
      # @param [Symbol] resumable_policy 分片上传策略。
      #   默认为 :auto，表示当文件大于 upload_threshold 时使用分片上传，否则使用表单上传。
      #   如果设置为 :always，表示总是使用分片上传。
      #   如果设置为 :never，表示总是使用表单上传。
      #   注意，如果是上传数据流而非文件，将总是采用分片上传的方式。
      # @param [Integer] upload_threshold 配合 resumable_policy 决定上传策略
      # @param [Bool] https 批处理操作是否使用 HTTPS 协议发送
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::Storage::Uploader::ChecksumError] 校验和出错
      # @return [QiniuNg::Storage::Uploader::Result] 返回上传结果
      def upload(filepath: nil, stream: nil, key: nil, upload_token:, params: {}, meta: {}, filename: nil,
                 recorder: Recorder::FileRecorder.new, mime_type: DEFAULT_MIME, disable_checksum: false,
                 upload_threshold: Config.upload_threshold, resumable_policy: :auto, https: nil, **options)
        if !filepath || resumable_policy == :always ||
           resumable_policy != :never && File.size(filepath) > upload_threshold
          if filepath
            @resumable_uploader.sync_upload_file(filepath, key: key, upload_token: upload_token, params: params,
                                                           meta: meta, filename: filename, recorder: recorder,
                                                           mime_type: mime_type, disable_checksum: disable_checksum,
                                                           https: https, **options)
          elsif stream
            @resumable_uploader.sync_upload_stream(stream, key: key, upload_token: upload_token, params: params,
                                                           meta: meta, filename: filename, recorder: recorder,
                                                           mime_type: mime_type, disable_checksum: disable_checksum,
                                                           https: https, **options)
          else
            raise ArgumentError, 'either filepath or stream must be specified to upload'
          end
        else
          @form_uploader.sync_upload_file(filepath, key: key, upload_token: upload_token, params: params, meta: meta,
                                                    filename: filename, mime_type: mime_type,
                                                    disable_checksum: disable_checksum, https: https, **options)
        end
      end
    end
  end
end
