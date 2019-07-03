# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
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
require 'qiniu_ng/http/middleware'
require 'qiniu_ng/http/client'
require 'qiniu_ng/http/response'
require 'qiniu_ng/storage/model/entry'
require 'qiniu_ng/storage/model/fetched_entry'
require 'qiniu_ng/storage/model/listed_entry'
require 'qiniu_ng/storage/model/async_fetch_result'
require 'qiniu_ng/storage/model/upload_policy'
require 'qiniu_ng/storage/model/storage_type'
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
    end
  end

  def self.config(use_https: nil,
                  batch_max_size: nil,
                  upload_threshold: nil,
                  upload_token_lifetime: nil,
                  download_url_lifetime: nil,
                  upload_block_size: nil,
                  file_recorder_path: nil,
                  **opts, &block)
    Config.use_https = use_https unless use_https.nil?
    Config.batch_max_size = batch_max_size unless batch_max_size.nil?
    Config.upload_threshold = upload_threshold unless upload_threshold.nil?
    Config.default_file_recorder_path = file_recorder_path unless file_recorder_path.nil?
    Config.default_upload_token_lifetime = upload_token_lifetime unless upload_token_lifetime.nil?
    Config.default_download_url_lifetime = download_url_lifetime unless download_url_lifetime.nil?
    Config.default_upload_block_size = upload_block_size unless upload_block_size.nil?
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
         upload_block_size: 1 << 22) do |conn|
    conn.adapter Faraday.default_adapter
  end
end
