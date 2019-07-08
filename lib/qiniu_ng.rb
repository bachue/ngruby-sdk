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
require 'qiniu_ng/http/error'
require 'qiniu_ng/http/error_code'
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
require 'qiniu_ng/storage/public_url'
require 'qiniu_ng/storage/private_url'
require 'qiniu_ng/storage/upload_token'
require 'qiniu_ng/storage/life_cycle_rules'
require 'qiniu_ng/storage/bucket_event_rules'
require 'qiniu_ng/storage/cors_rules'
require 'qiniu_ng/cdn/granularity'
require 'qiniu_ng/cdn/log'
require 'qiniu_ng/cdn/error'
require 'qiniu_ng/cdn/manager'
require 'qiniu_ng/cdn/refresh_result'
require 'qiniu_ng/cdn/prefetch_result'

# 下一代七牛 Ruby SDK
module QiniuNg
  include Common
  include Utils
  # 全局配置
  class Config
    class << self
      attr_accessor :use_https
      attr_accessor :batch_max_size
      attr_accessor :upload_threshold
      attr_accessor :default_upload_block_size
      attr_accessor :default_file_recorder_path
      attr_accessor :default_upload_token_lifetime
      attr_accessor :default_download_url_lifetime
      attr_accessor :default_faraday_options
      attr_accessor :default_faraday_config
      attr_accessor :default_http_request_retries
      attr_accessor :default_http_request_retry_delay
      attr_accessor :default_json_marshaler
      attr_accessor :default_json_unmarshaler
    end
  end

  def self.new_client(access_key:, secret_key:, domains_manager: nil)
    auth = Utils::Auth.new(access_key: access_key, secret_key: secret_key)
    Client.new(auth, domains_manager: domains_manager)
  end

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
    Config.default_faraday_options = opts unless opts.empty?
    Config.default_faraday_config = block if block_given?
    nil
  end

  config(use_https: false,
         batch_max_size: 10_000,
         file_recorder_path: '/tmp',
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
         end) do |conn|
    conn.adapter Faraday.default_adapter
  end
end
