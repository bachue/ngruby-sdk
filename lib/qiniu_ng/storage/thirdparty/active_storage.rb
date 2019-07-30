# frozen_string_literal: true

require 'base64'

# 本文件提供对 ActiveStorage 的集成

module ActiveStorage
  class Service
    # QiniuNg 的 ActiveStorage 插件，支持通过 ActiveStorage API 将文件上传至七牛云
    #
    # {区域代号参考文档}[https://developer.qiniu.com/kodo/manual/1671/region-endpoint]
    #
    # @example 在 config/storage.yml 中配置七牛云
    #   qiniu_ng:
    #     service: QiniuNg
    #     access_key: '<Qiniu AccessKey>'
    #     secret_key: '<Qiniu SecretKey>'
    #     bucket: '<Qiniu BucketName>'
    #
    # @example 可以支持的配置选项
    #   access_key: 七牛 Access Key，必填
    #   secret_key: 七牛 Secret Key，必填
    #   bucket: 七牛存储空间名称，必填
    #   bucket_zone: 七牛存储空间所在区域，需要传入区域代号，选填
    #   bucket_domains: 七牛存储空间的下载域名列表，选填
    #   use_https: 是否使用 HTTPS 访问 API，选填
    #   https_download_url: 是否生成 HTTPS 协议的文件下载地址，选填
    #   overwritable: 如果文件在存储空间中已经存在，是否覆盖文件，选填
    #   upload_block_size: 当使用分片方式上传文件时，设置每个分片的尺寸。单位为字节。该尺寸必须是 4 MB 的整数倍，选填
    #   upload_token_expires_in: 七牛上传凭证有效期，选填
    #   auto_detect_mime: 是否自动侦测上传文件的 MIME 类型，选填
    #   infrequent_storage: 是否使用低频存储，选填
    #   expire_after_days: 设置上传文件的生命周期，单位为天，选填
    #   delete_after_days: 与 qiniu_expire_after_days 作用完全相同，仅需要设置任意一个即可，选填
    #   callback_urls: 回调业务服务器的 URL 列表，选填
    #   callback_host: 回调 HOST，选填
    #   callback_body: 回调请求的内容，选填
    #   callback_body_type: 回调请求的内容类型，默认为 application/x-www-form-urlencoded，选填
    #   persistent_ops: 预转持久化处理指令列表，选填
    #   persistent_notify_url: 预转持久化处理完毕后回调业务服务器的 URL，选填
    #   persistent_pipeline: 转码队列名，选填
    #   cdn_timestamp_anti_leech_encrypt_key: 七牛 CDN Key，选填
    class QiniuNgService < Service
      # @!visibility private
      def initialize(access_key:, secret_key:, bucket:, bucket_zone: nil, bucket_domains: nil,
                     use_https: nil, https_download_url: nil,
                     overwritable: false, upload_block_size: QiniuNg::Config.default_upload_block_size,
                     upload_token_expires_in: nil, auto_detect_mime: false, infrequent_storage: false,
                     expire_after_days: nil, delete_after_days: nil,
                     callback_urls: nil, callback_host: nil, callback_body: nil, callback_body_type: nil,
                     persistent_ops: nil, persistent_notify_url: nil, persistent_pipeline: nil,
                     cdn_timestamp_anti_leech_encrypt_key: nil)
        @client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
        zone = QiniuNg::Zone.send(bucket_zone) if bucket_zone
        @bucket = @client.bucket(bucket, zone: zone, domains: bucket_domains)
        @uploader = @bucket.uploader(block_size: upload_block_size)
        @use_https = use_https
        @https_download_url = https_download_url
        @overwritable = overwritable
        @upload_token_expires_in = upload_token_expires_in
        @auto_detect_mime = auto_detect_mime
        @infrequent_storage = infrequent_storage
        @expire_after_days = expire_after_days
        @delete_after_days = delete_after_days
        @callback_urls = callback_urls
        @callback_host = callback_host
        @callback_body = callback_body
        @callback_body_type = callback_body_type
        @persistent_ops = persistent_ops
        @persistent_notify_url = persistent_notify_url
        @persistent_pipeline = persistent_pipeline
        @cdn_timestamp_anti_leech_encrypt_key = cdn_timestamp_anti_leech_encrypt_key
      end

      # 上传 IO 至云存储
      #
      # @param [String] key 上传至七牛后的文件名
      # @param [#read] io 文件流
      # @param [String] checksum 文件内容的 MD5 值（经过 Base64 编码）
      # @param [String] content_type 文件 MIME 类型
      def upload(key, io, checksum: nil, content_type: nil, **_options)
        instrument :upload, key: key, checksum: checksum do
          @uploader.upload(key: key, stream: io, mime_type: content_type,
                           upload_token: make_upload_token(key, content_type: content_type),
                           https: @use_https)
          verify_md5!(key, checksum) if checksum
        end
      end

      # 从云存储下载文件内容
      #
      # @param [String] key 文件名
      # @yield [chunk] 传入 Block 获取文件内容分片
      # @yieldparam chunk [String] 文件内容分片
      # @return [String] 文件内容
      def download(key, &block)
        if block_given?
          instrument :streaming_download, key: key do
            stream(key, &block)
          end
        else
          instrument :download, key: key do
            read_full(key)
          end
        end
      end

      # 从云存储下载文件部分内容
      #
      # @param [String] key 文件名
      # @param [Range] range 下载范围
      # @yield [chunk] 传入 Block 获取文件内容分片
      # @yieldparam chunk [String] 文件内容分片
      # @return [String] 文件内容
      def download_chunk(key, range)
        instrument :download_chunk, key: key, range: range do
          read_full(key, range: range)
        end
      end

      # 从云存储删除文件
      #
      # @param [String] key 要删除的文件名
      def delete(key)
        instrument :delete, key: key do
          entry_for(key).delete
        end
      end

      # 从云存储删除带有指定前缀的文件
      #
      # @param [String] prefix 要删除的文件名称前缀
      def delete_prefixed(prefix)
        instrument :delete_prefixed, prefix: prefix do
          @bucket.batch do |batch|
            @bucket.files(prefix: prefix).each do |file|
              batch.delete(file.key)
            end
          end
        end
      end

      # 在云存储上是否存在该文件
      #
      # @param [String] key 文件名
      # @return [Boolean] 是否存在该文件
      def exist?(key)
        instrument :exist, key: key do |payload|
          answer = entry_for(key).exists?
          payload[:exist] = answer
          answer
        end
      end

      # rubocop:disable Metrics/LineLength

      # 获取七牛文件的下载地址
      #
      # @param [String] fop 数据处理参数，不要与 style 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] style 数据处理样式，不要与 fop 同时设置。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [Integer, Hash, QiniuNg::Duration] expires_in 下载地址有效期
      # @return [QiniuNg::Storage::PublicURL, QiniuNg::Storage::PrivateURL, QiniuNg::Storage::TimestampAntiLeechURL, nil]
      #   返回文件的下载地址，将会自动根据配置返回正确的下载地址。如果没有提供域名且存储空间在七牛没有绑定任何域名将返回 nil
      def url(key, expires_in: nil, fop: nil, style: nil, filename:, **options)
        instrument :url, key: key do |payload|
          generated_url = generate_url(key, expires_in: expires_in,
                                            fop: fop, style: style, filename: filename, **options)
          payload[:url] = generated_url
          generated_url
        end
      end

      # rubocop:enable Metrics/LineLength

      private

      def stream(key, range: nil)
        generate_url(key).reader(range: range).each_chunk { |chunk| yield chunk }
      rescue Down::ClientError => e
        raise ActiveStorage::FileNotFoundError if e.response.code == '404'

        raise
      end

      def read_full(key, range: nil)
        generate_url(key).reader(range: range).read
      rescue Down::ClientError => e
        raise ActiveStorage::FileNotFoundError if e.response.code == '404'

        raise
      end

      def entry_for(key)
        @bucket.entry(key)
      end

      def generate_url(key, expires_in: nil, fop: nil, style: nil, filename: nil, **_options)
        url = entry_for(key).download_url(filename: filename, style: style, fop: fop, https: @https_download_url)
        if @cdn_timestamp_anti_leech_encrypt_key
          url = url.timestamp_anti_leech(encrypt_key: @cdn_timestamp_anti_leech_encrypt_key,
                                         lifetime: expires_in)
        elsif expires_in || @bucket.private?
          url = url.private(lifetime: expires_in)
        end
        url
      end

      def make_upload_token(key, content_type:)
        force_key = key if @overwritable
        @bucket.upload_token(key: force_key) do |policy|
          policy.set_token_lifetime(@upload_token_expires_in) if @upload_token_expires_in
          policy.insert_only! unless @overwritable
          policy.detect_mime! if @auto_detect_mime || content_type.nil?
          policy.infrequent_storage! if @infrequent_storage
          unless @callback_urls.nil? || @callback_urls.empty?
            policy.set_callback(@callback_urls,
                                host: @callback_host, body: @callback_body, body_type: @callback_body_type)
          end
          unless @persistent_ops.nil? || @persistent_ops.empty?
            policy.set_persistent_ops(@persistent_ops, notify_url: @persistent_notify_url,
                                                       pipeline: @persistent_pipeline)
          end
          policy.set_file_lifetime(days: @delete_after_days) if @delete_after_days
        end
      end

      def verify_md5!(key, md5_base64)
        md5_hex = Base64.strict_decode64(md5_base64).unpack('H*').first
        raise ActiveStorage::IntegrityError if entry_for(key).md5 != md5_hex
      rescue QiniuNg::HTTP::NoURLAvailable
        # do nothing
        nil
      end
    end
  end
end
