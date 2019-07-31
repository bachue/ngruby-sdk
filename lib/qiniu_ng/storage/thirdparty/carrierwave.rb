# frozen_string_literal: true

# 本文件提供对 CarrierWave 的集成，感谢 [carrierwave-qiniu](https://github.com/huobazi/carrierwave-qiniu.git)

require 'tempfile'
require 'forwardable'

module CarrierWave
  module Storage
    # QiniuNg 的 CarrierWave 插件，支持通过 CarrierWave 的 API 将文件上传至七牛云
    #
    # @example 在 Rails 中的 config/initializers/carrierwave.rb 配置七牛作为存储后端
    #   CarrierWave.configure do |config|
    #     config.storage = :qiniu_ng
    #     config.qiniu_access_key = '<Qiniu AccessKey>'
    #     config.qiniu_secret_key = '<Qiniu SecretKey>'
    #     config.qiniu_bucket_name = '<Qiniu BucketName>'
    #   end
    #
    # @example 生成 Uploader 类
    #   class AvatarUploader < CarrierWave::Uploader::Base
    #     storage :qiniu_ng        # 设置后端存储为七牛云
    #   end
    #
    # @example 生成 ActiveRecord 类
    #   class User < ActiveRecord::Base
    #     mount_uploader :avatar, AvatarUploader
    #   end
    #
    # @example 通过 ActiveRecord 向七牛云上传 / 下载数据
    #   user = User.new
    #   user.avatar = params[:file]                      # 将用户上传的文件赋值给 avatar 字段
    #   user.save!                                       # 保存数据到数据库，并将用户上传的文件上传至七牛云
    #   user.avatar.url                                  # 获取上传文件的下载地址
    #   user.avatar.url(style: 'small')                  # 获取带有样式的下载地址
    #   user.avatar.url(fop: 'imageView/2/h/200')        # 获取带有数据处理的下载地址
    #   user.avatar.url.download_to('<Local File Path>') # 下载上传的文件到本地
    #
    # @example CarrierWave.configure 中可以支持的配置项
    #   qiniu_access_key: 七牛 Access Key，必填
    #   qiniu_secret_key: 七牛 Secret Key，必填
    #   qiniu_bucket_name: 七牛存储空间名称，必填
    #   qiniu_bucket_zone: 七牛存储空间所在区域，需要传入 QiniuNg::Zone 的实例，选填
    #   qiniu_bucket_domains: 七牛存储空间的下载域名列表，选填
    #   qiniu_use_https: 是否使用 HTTPS 访问 API，选填
    #   qiniu_overwritable: 如果文件在存储空间中已经存在，是否覆盖文件，选填
    #   qiniu_upload_block_size: 当使用分片方式上传文件时，设置每个分片的尺寸。单位为字节。该尺寸必须是 4 MB 的整数倍，选填
    #   qiniu_upload_token_expires_in: 七牛上传凭证有效期，选填
    #   qiniu_auto_detect_mime: 是否自动侦测上传文件的 MIME 类型，选填
    #   qiniu_infrequent_storage: 是否使用低频存储，选填
    #   qiniu_expire_after_days: 设置上传文件的生命周期，单位为天，选填
    #   qiniu_delete_after_days: 与 qiniu_expire_after_days 作用完全相同，仅需要设置任意一个即可，选填
    #   qiniu_callback_urls: 回调业务服务器的 URL 列表，选填
    #   qiniu_callback_host: 回调 HOST，选填
    #   qiniu_callback_body: 回调请求的内容，选填
    #   qiniu_callback_body_type: 回调请求的内容类型，默认为 application/x-www-form-urlencoded，选填
    #   qiniu_persistent_ops: 预转持久化处理指令列表，选填
    #   qiniu_persistent_notify_url: 预转持久化处理完毕后回调业务服务器的 URL，选填
    #   qiniu_persistent_pipeline: 转码队列名，选填
    #   qiniu_url_expires_in: 下载地址有效期，选填
    #   qiniu_cdn_timestamp_anti_leech_encrypt_key: 七牛 CDN Key，选填
    class QiniuNg < CarrierWave::Storage::File
      # @!visibility private
      module Configuration
        # 由于 CarrierWave 依赖 ActiveSupport，因此可以在组件内部直接调用 ActiveSupport 方法
        extend ActiveSupport::Concern

        included do
          add_config :qiniu_access_key
          add_config :qiniu_secret_key
          add_config :qiniu_bucket_name
          add_config :qiniu_bucket_zone
          add_config :qiniu_bucket_domains
          add_config :qiniu_use_https
          add_config :qiniu_overwritable
          add_config :qiniu_upload_block_size
          add_config :qiniu_upload_token_expires_in
          add_config :qiniu_auto_detect_mime
          add_config :qiniu_infrequent_storage
          add_config :qiniu_expire_after_days
          add_config :qiniu_delete_after_days
          add_config :qiniu_callback_urls
          add_config :qiniu_callback_host
          add_config :qiniu_callback_body
          add_config :qiniu_callback_body_type
          add_config :qiniu_persistent_ops
          add_config :qiniu_persistent_notify_url
          add_config :qiniu_persistent_pipeline
          add_config :qiniu_url_expires_in
          add_config :qiniu_cdn_timestamp_anti_leech_encrypt_key

          reset_qiniu_config
        end

        class_methods do
          def reset_qiniu_config
            configure do |config|
              config.qiniu_access_key = nil
              config.qiniu_secret_key = nil
              config.qiniu_bucket_name = nil
              config.qiniu_bucket_zone = nil
              config.qiniu_bucket_domains = nil
              config.qiniu_use_https = nil
              config.qiniu_overwritable = nil
              config.qiniu_upload_block_size = ::QiniuNg::Config.default_upload_block_size
              config.qiniu_upload_token_expires_in = nil
              config.qiniu_auto_detect_mime = true
              config.qiniu_infrequent_storage = false
              config.qiniu_expire_after_days = nil
              config.qiniu_delete_after_days = nil
              config.qiniu_callback_urls = nil
              config.qiniu_callback_host = nil
              config.qiniu_callback_body = nil
              config.qiniu_callback_body_type = nil
              config.qiniu_persistent_ops = nil
              config.qiniu_persistent_notify_url = nil
              config.qiniu_persistent_pipeline = nil
              config.qiniu_url_expires_in = nil
              config.qiniu_cdn_timestamp_anti_leech_encrypt_key = nil
            end
          end
        end
      end

      # @!visibility private
      class Client
        # @!visibility private
        def initialize(
          access_key:, secret_key:, bucket_name:, bucket_zone: nil, bucket_domains: nil,
          use_https: nil, overwritable: nil, upload_block_size: ::QiniuNg::Config.default_upload_block_size,
          upload_token_expires_in: nil, auto_detect_mime: true, infrequent_storage: false,
          expire_after_days: nil, delete_after_days: nil,
          callback_urls: nil, callback_host: nil, callback_body: nil, callback_body_type: nil,
          persistent_ops: nil, persistent_notify_url: nil, persistent_pipeline: nil,
          url_expires_in: nil, cdn_timestamp_anti_leech_encrypt_key: nil
        )
          client = ::QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
          @bucket = client.bucket(bucket_name, zone: bucket_zone, domains: bucket_domains)
          @uploader = @bucket.uploader(block_size: upload_block_size)
          @use_https = use_https
          @overwritable = overwritable
          @callback_urls = callback_urls
          @callback_host = callback_host
          @callback_body = callback_body
          @callback_body_type = callback_body_type
          @persistent_ops = persistent_ops
          @persistent_notify_url = persistent_notify_url
          @persistent_pipeline = persistent_pipeline
          @upload_token_expires_in = upload_token_expires_in
          @auto_detect_mime = auto_detect_mime
          @infrequent_storage = infrequent_storage
          @delete_after_days = delete_after_days || expire_after_days
          @url_expires_in = url_expires_in
          @cdn_timestamp_anti_leech_encrypt_key = cdn_timestamp_anti_leech_encrypt_key
        end

        # @!visibility private
        def store(file, key)
          @uploader.upload(filepath: file.path, key: key, upload_token: make_upload_token(key), https: @use_https)
        end

        # @!visibility private
        def download_url(key, style: nil, fop: nil, https: false)
          url = @bucket.entry(key).download_url(style: style, fop: fop, https: https)
          if @cdn_timestamp_anti_leech_encrypt_key
            url = url.timestamp_anti_leech(encrypt_key: @cdn_timestamp_anti_leech_encrypt_key,
                                           lifetime: @url_expires_in)
          elsif @url_expires_in || @bucket.private?
            url = url.private(lifetime: @url_expires_in)
          end
          url
        end

        # @!visibility private
        def entry(key)
          @bucket.entry(key)
        end

        private

        def make_upload_token(key)
          force_key = key if @overwritable
          @bucket.upload_token(key: force_key) do |policy|
            policy.set_token_lifetime(@upload_token_expires_in) if @upload_token_expires_in
            policy.insert_only! unless @overwritable
            policy.detect_mime! if @auto_detect_mime
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
      end

      # CarrierWave 内的七牛空间文件
      class File
        extend Forwardable

        # @!visibility private
        attr_reader :key

        # @!visibility private
        def initialize(uploader, key)
          @uploader = uploader
          @key = key
          @client = Client.new access_key: uploader.qiniu_access_key,
                               secret_key: uploader.qiniu_secret_key,
                               bucket_name: uploader.qiniu_bucket_name,
                               bucket_zone: uploader.qiniu_bucket_zone,
                               bucket_domains: uploader.qiniu_bucket_domains,
                               use_https: uploader.qiniu_use_https,
                               overwritable: uploader.qiniu_overwritable,
                               upload_block_size: uploader.qiniu_upload_block_size,
                               upload_token_expires_in: uploader.qiniu_upload_token_expires_in,
                               auto_detect_mime: uploader.qiniu_auto_detect_mime,
                               infrequent_storage: uploader.qiniu_infrequent_storage,
                               expire_after_days: uploader.qiniu_expire_after_days,
                               delete_after_days: uploader.qiniu_delete_after_days,
                               callback_urls: uploader.qiniu_callback_urls,
                               callback_host: uploader.qiniu_callback_host,
                               callback_body: uploader.qiniu_callback_body,
                               callback_body_type: uploader.qiniu_callback_body_type,
                               persistent_ops: uploader.qiniu_persistent_ops,
                               persistent_notify_url: uploader.qiniu_persistent_notify_url,
                               persistent_pipeline: uploader.qiniu_persistent_pipeline,
                               url_expires_in: uploader.qiniu_url_expires_in,
                               cdn_timestamp_anti_leech_encrypt_key: uploader.qiniu_cdn_timestamp_anti_leech_encrypt_key
        end

        # rubocop:disable Metrics/LineLength

        # 获取七牛文件的下载地址
        #
        # @param [String] fop 数据处理参数，不要与 style 同时设置。
        #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
        # @param [String] style 数据处理样式，不要与 fop 同时设置。
        #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @return [QiniuNg::Storage::PublicURL, QiniuNg::Storage::PrivateURL, QiniuNg::Storage::TimestampAntiLeechURL, nil]
        #   返回文件的下载地址，将会自动根据配置返回正确的下载地址。如果没有提供域名且存储空间在七牛没有绑定任何域名将返回 nil
        def url(style: nil, fop: nil, https: false)
          @client.download_url(@key, style: style, fop: fop, https: https)
        end
        alias path url

        # rubocop:enable Metrics/LineLength
        # rubocop:disable Naming/PredicateName

        # #path 返回 Pathname 还是 String
        #
        # 该方法总是返回 false
        def is_path?
          false
        end

        # rubocop:enable Naming/PredicateName

        # 获取 QiniuNg::Storage::Entry 实例
        #
        # @return [QiniuNg::Storage::Entry] 返回七牛空间内的文件
        def entry
          @client.entry(@key)
        end
        def_delegators :entry, *::QiniuNg::Storage::Entry.public_instance_methods(false)

        # 上传指定的文件到云存储
        # @param [File, CarrierWave::SanitizedFile] file 要上传的文件
        def store(file)
          @client.store(file, @key)
        end

        # 文件在云存储上是否存在
        # @return [Boolean] 文件在云存储上是否存在
        def exists?
          !file_info.nil?
        end

        # 文件的 MIME 类型
        # @return [String] 文件的 MIME 类型
        def content_type
          file_info&.mime_type || 'application/octet-stream'
        end
        alias mime_type content_type

        # 文件的大小，单位为字节
        # @return [Integer] 文件的大小，单位为字节
        def size
          file_info&.file_size
        end

        # 文件名
        # @return [String] 文件名称
        def filename
          ::File.basename(@key)
        end
        alias identifier filename

        # 文件基本名称
        # @return [String] 文件基本名称
        def basename
          split_extension(@key).first
        end

        # 文件扩展名称
        # @return [String] 文件扩展名称
        def extension
          split_extension(@key).last
        end

        # 获取文件的二进制字符串
        # @return [String] 获取文件的二进制字符串
        def read
          Tempfile.create('qiniu_ng', nil, mode: 0o600, encoding: 'ascii-8bit') do |file|
            @client.download_url(@key).download_to(file.path)
            file.read
          end
        end

        # 获取文件
        #
        # 该方法将会将文件下载至本地临时目录然后返回
        #
        # @return [File] 获取文件
        def to_file
          tempfile = Tempfile.create('qiniu_ng', nil, mode: 0o600, encoding: 'ascii-8bit')
          @client.download_url(@key).download_to(tempfile.path)
          ::File.open(tempfile.path, 'r+')
        ensure
          tempfile&.close
        end

        # 文件内容是否为空
        # @return [Boolean] 文件内容是否为空
        def empty?
          file_size = size
          file_size.nil? || file_size.zero?
        end

        private

        def file_info
          @client.entry(@key).stat
        rescue ::QiniuNg::HTTP::ResourceNotFound
          nil
        end

        def split_extension(filename)
          extension_matchers = [
            /\A(.+)\.(tar\.([glx]?z|bz2))\z/, # matches "something.tar.gz"
            /\A(.+)\.([^\.]+)\z/ # matches "something.jpg"
          ]

          extension_matchers.each do |regexp|
            return Regexp.last_match(1), Regexp.last_match(2) if filename =~ regexp
          end
          [filename, ''] # In case we weren't able to split the extension
        end
      end

      # 上传指定的文件到云存储
      # @param [File, CarrierWave::SanitizedFile] file 要上传的文件
      # @return [CarrierWave::Storage::QiniuNg::File] 返回已经上传的文件实例
      def store!(file)
        super
        f = ::CarrierWave::Storage::QiniuNg::File.new(uploader, uploader.store_path)
        f.store(file)
        f
      end

      # 下载文件
      # @param [String] key 文件标识符
      # @return [CarrierWave::Storage::QiniuNg::File] 返回文件实例
      def retrieve!(key)
        ::CarrierWave::Storage::QiniuNg::File.new(uploader, uploader.store_path(key))
      end
    end
  end
end

::CarrierWave.configure do |config|
  config.storage_engines[:qiniu_ng] = '::CarrierWave::Storage::QiniuNg'
end
::CarrierWave::Uploader::Base.include(::CarrierWave::Storage::QiniuNg::Configuration)
