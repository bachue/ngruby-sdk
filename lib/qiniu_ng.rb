# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'concurrent-ruby'
require 'qiniu_ng/version'
require 'qiniu_ng/client'
require 'qiniu_ng/common/constant'
require 'qiniu_ng/common/zone'
require 'qiniu_ng/common/auto_zone'
require 'qiniu_ng/utils/auth'
require 'qiniu_ng/utils/bool'
require 'qiniu_ng/utils/etag'
require 'qiniu_ng/utils/duration'
require 'qiniu_ng/http/error'
require 'qiniu_ng/http/domains_manager'
require 'qiniu_ng/http/middleware'
require 'qiniu_ng/http/client'
require 'qiniu_ng/http/response'
require 'qiniu_ng/storage/model/entry'
require 'qiniu_ng/storage/model/fetched_entry'
require 'qiniu_ng/storage/model/listed_entry'
require 'qiniu_ng/storage/model/async_fetch_result'
require 'qiniu_ng/storage/model/upload_policy'
require 'qiniu_ng/storage/model/storage_type'
require 'qiniu_ng/storage/model/life_cycle_rule'
require 'qiniu_ng/storage/model/bucket_event_type'
require 'qiniu_ng/storage/model/bucket_event_rule'
require 'qiniu_ng/storage/model/cors_rule'
require 'qiniu_ng/storage/recorder/file_recorder'
require 'qiniu_ng/storage/uploader'
require 'qiniu_ng/storage/uploader/uploader_base'
require 'qiniu_ng/storage/uploader/form_uploader'
require 'qiniu_ng/storage/uploader/resumable_uploader'
require 'qiniu_ng/storage/bucket_manager'
require 'qiniu_ng/storage/bucket'
require 'qiniu_ng/storage/entry'
require 'qiniu_ng/storage/op'
require 'qiniu_ng/storage/batch_operations'
require 'qiniu_ng/storage/url'
require 'qiniu_ng/storage/public_url'
require 'qiniu_ng/storage/private_url'
require 'qiniu_ng/storage/timestamp_anti_leech_url'
require 'qiniu_ng/storage/upload_token'
require 'qiniu_ng/storage/life_cycle_rules'
require 'qiniu_ng/storage/bucket_event_rules'
require 'qiniu_ng/storage/cors_rules'
require 'qiniu_ng/processing/operation_manager'
require 'qiniu_ng/processing/persistent_id'
require 'qiniu_ng/processing/pfop_result'
require 'qiniu_ng/processing/pfop_results'
require 'qiniu_ng/processing/pfop_status'
require 'qiniu_ng/cdn/granularity'
require 'qiniu_ng/cdn/log'
require 'qiniu_ng/cdn/error'
require 'qiniu_ng/cdn/manager'
require 'qiniu_ng/cdn/refresh_request'
require 'qiniu_ng/cdn/prefetch_request'
require 'qiniu_ng/cdn/log_file'
require 'qiniu_ng/cdn/log_files'

# 下一代七牛 Ruby SDK
#
# 这是 QiniuNg-Ruby 的主要名字空间。用于配置全局设置，以及创建七牛客户端
#
# @example 全局配置七牛客户端
#   QiniuNg.config use_https: true
#
# @example 创建七牛客户端
#   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
#
module QiniuNg
  include Common
  include Utils
  # 全局配置
  class Config
    class << self
      # 是否使用 HTTPS
      #
      # @return [Boolean]
      attr_accessor :use_https

      # 批处理操作的单次最大处理数量，如果批处理操作中操作数大于该值，将自动被分割为多次批处理操作
      #
      # @return [Integer]
      attr_accessor :batch_max_size

      # 如果上传文件尺寸大于该值，将自动使用分片上传，否则，使用表单上传。单位为字节
      #
      # @return [Integer]
      attr_accessor :upload_threshold

      # 分片上传时，每个分片的尺寸。单位为字节
      #
      # @return [Integer]
      attr_accessor :default_upload_block_size

      # 分片上传时，用于保存上传信息的目录
      #
      # @return [String]
      attr_accessor :default_file_recorder_path

      # 默认生成的上传策略的有效期。单位为秒
      #
      # @return [Integer]
      attr_accessor :default_upload_token_lifetime

      # 默认生成的下载地址的有效期。单位为秒
      #
      # @return [Integer]
      attr_accessor :default_download_url_lifetime

      # Faraday 配置参数
      #
      # @return [Hash]
      attr_accessor :default_faraday_options

      # @!visibility private
      attr_accessor :default_faraday_config

      # 默认 HTTP 请求在失败后的重试次数，当且仅当 HTTP 请求幂等时才会重试
      #
      # @return [Integer]
      attr_accessor :default_http_request_retries

      # 默认 HTTP 请求在重试前的等待间隔时间。单位为秒
      #
      # @return [Integer]
      attr_accessor :default_http_request_retry_delay

      # JSON 编码器
      #
      # @return [Lambda]
      attr_accessor :default_json_marshaler

      # JSON 解码器
      #
      # @return [Lambda]
      attr_accessor :default_json_unmarshaler

      # 域名管理器。默认将自动初始化
      #
      # @return [QiniuNg::HTTP::DomainsManager]
      attr_accessor :default_domains_manager
    end
  end

  # 创建新的七牛客户端
  #
  # @example
  #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
  #
  # @param [String] access_key 七牛 Access Key
  # @param [String] secret_key 七牛 Secret Key
  # @param [QiniuNg::HTTP::DomainsManager] domains_manager 域名管理器
  # @return [QiniuNg::Client] 新建的七牛客户端
  def self.new_client(access_key:, secret_key:, domains_manager: Config.default_domains_manager)
    auth = Utils::Auth.new(access_key: access_key, secret_key: secret_key)
    Client.new(auth, domains_manager: domains_manager)
  end

  # 更新全局配置
  #
  # @example
  #   QiniuNg.config(use_https: true) do |conn|
  #     conn.adapter :typhoeus # 设置 Faraday 适配器为 Typhoeus
  #   end
  #
  # @param [Boolean] use_https 是否使用 HTTPS，默认为 false
  # @param [Integer] batch_max_size 批处理操作的单次最大处理数量，如果批处理操作中操作数大于该值，将自动被分割为多次批处理操作，默认值为 1000
  # @param [Integer] upload_threshold 如果上传文件尺寸大于该值，将自动使用分片上传，否则，使用表单上传。单位为字节。默认为 4 MB
  # @param [Integer] upload_token_lifetime 分片上传时，每个分片的尺寸。单位为秒。默认为 1 小时
  # @param [Integer] download_url_lifetime 默认生成的下载地址的有效期。单位为秒。默认为 1 小时
  # @param [Integer] upload_block_size 分片上传时，每个分片的尺寸。单位为字节。默认为 4 MB
  # @param [String] file_recorder_path 分片上传时，用于保存上传信息的目录。如果给定的目录地址不存在，将会自动创建。默认为 /tmp/qiniu_ng
  # @param [Integer] http_request_retries 默认 HTTP 请求在失败后的重试次数，当且仅当 HTTP 请求幂等时才会重试。默认为 3 次
  # @param [Integer] http_request_retry_delay 默认 HTTP 请求在重试前的等待间隔时间。单位为秒。默认为 0.5 秒
  # @param [Lambda] json_marshaler JSON 编码器。默认使用 JSON.generate 生成 JSON 数据
  # @param [Lambda] json_unmarshaler JSON 解码器。默认使用 JSON.parse 解析 JSON 数据
  # @param [QiniuNg::HTTP::DomainsManager] domains_manager 域名管理器
  # @yield [conn] 配置 Faraday 参数
  # @yieldparam conn [Faraday::Connection] Faraday 参数
  def self.config(use_https: nil,
                  batch_max_size: nil,
                  upload_threshold: nil,
                  upload_token_lifetime: nil,
                  download_url_lifetime: nil,
                  upload_block_size: nil,
                  file_recorder_path: nil,
                  http_request_retries: nil,
                  http_request_retry_delay: nil,
                  json_marshaler: nil,
                  json_unmarshaler: nil,
                  domains_manager: nil,
                  **opts, &block)
    Config.use_https = use_https unless use_https.nil?
    Config.batch_max_size = batch_max_size unless batch_max_size.nil?
    Config.upload_threshold = upload_threshold unless upload_threshold.nil?
    Config.default_file_recorder_path = file_recorder_path unless file_recorder_path.nil?
    Config.default_upload_token_lifetime = upload_token_lifetime unless upload_token_lifetime.nil?
    Config.default_download_url_lifetime = download_url_lifetime unless download_url_lifetime.nil?
    Config.default_upload_block_size = upload_block_size unless upload_block_size.nil?
    Config.default_http_request_retries = http_request_retries unless http_request_retries.nil?
    Config.default_http_request_retry_delay = http_request_retry_delay unless http_request_retry_delay.nil?
    Config.default_json_marshaler = json_marshaler unless json_marshaler.nil?
    Config.default_json_unmarshaler = json_unmarshaler unless json_unmarshaler.nil?
    Config.default_domains_manager = domains_manager unless domains_manager.nil?
    Config.default_faraday_options = opts unless opts.empty?
    Config.default_faraday_config = block if block_given?
    nil
  end

  config(use_https: false,
         batch_max_size: 10_000,
         file_recorder_path: '/tmp/qiniu_ng',
         upload_token_lifetime: 3600,
         download_url_lifetime: 3600,
         upload_threshold: 1 << 22,
         upload_block_size: 1 << 22,
         http_request_retries: 3,
         http_request_retry_delay: 0.5,
         json_marshaler: lambda do |obj, *args|
           require 'json' unless defined?(JSON)
           JSON.generate(obj, *args)
         end,
         json_unmarshaler: lambda do |data, *args|
           require 'json' unless defined?(JSON)
           JSON.parse(data, *args)
         end,
         domains_manager: HTTP::DomainsManager.new) do |conn|
    conn.adapter Faraday.default_adapter
  end
end
