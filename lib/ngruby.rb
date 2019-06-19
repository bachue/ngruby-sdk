# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'ngruby/version'
require 'ngruby/client'
require 'ngruby/common/zone'
require 'ngruby/common/auto_zone'

# 下一代七牛 Ruby SDK
module Ngruby
  # 全局配置
  class Config
    class << self
      attr_accessor :default_faraday_connection
      attr_accessor :default_faraday_options
      attr_accessor :default_faraday_config
    end
  end

  Config.default_faraday_options = {}
  Config.default_faraday_config = ->(conn) { conn.adapter Faraday.default_adapter }
  Config.default_faraday_connection = lambda do
    opts = Config.default_faraday_options
    opts = opts.call if opts.respond_to?(:call)
    Faraday.new(nil, opts) do |conn|
      conn.request :retry
      conn.response :json, content_type: /\bjson$/
      conn.response :raise_error
      Config.default_faraday_config.call(conn)
    end
  end
end
