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
require 'qiniu_ng/storage/model/upload_policy'
require 'qiniu_ng/storage/model/storage_type'
require 'qiniu_ng/storage/bucket_manager'
require 'qiniu_ng/storage/bucket'
require 'qiniu_ng/storage/entry'
require 'qiniu_ng/storage/op'
require 'qiniu_ng/storage/download_url'

# 下一代七牛 Ruby SDK
module QiniuNg
  include Common
  include Utils
  # 全局配置
  class Config
    class << self
      attr_accessor :use_https
      attr_accessor :default_faraday_options
      attr_accessor :default_faraday_config
    end
  end

  def self.config(use_https: nil, **opts, &block)
    Config.use_https = use_https unless use_https.nil?
    Config.default_faraday_options = opts unless opts.empty?
    Config.default_faraday_config = block if block_given?
    nil
  end

  config(use_https: false) do |conn|
    conn.adapter Faraday.default_adapter
  end
end
