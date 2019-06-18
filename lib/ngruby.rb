require 'faraday'
require 'faraday_middleware'
require 'ngruby/version'
require 'ngruby/client'
require 'ngruby/common/zone'
require 'ngruby/common/auto_zone'

module Ngruby
  class Error < StandardError; end
  class Config
    class << self
      attr_accessor :default_faraday_connection
    end
  end

  Config.default_faraday_connection = -> do
    Faraday.new do |conn|
      conn.request :retry
      conn.response :json, content_type: /\bjson$/
      conn.response :raise_error
      conn.adapter :net_http
    end
  end
end
