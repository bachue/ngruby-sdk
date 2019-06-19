# frozen_string_literal: true

require 'faraday'

module Ngruby
  # HTTP 客户端
  class Client
    attr_reader :access_key
    attr_reader :secret_key

    def initialize(
      access_key:,
      secret_key:,
      faraday: nil
    )
      @access_key = access_key
      @secret_key = secret_key
      @faraday_connection = faraday
      @faraday_connection ||= if Config.default_faraday_connection.respond_to?(:call)
                                Config.default_faraday_connection.call
                              else
                                Config.default_faraday_connection
                              end
    end
  end
end
