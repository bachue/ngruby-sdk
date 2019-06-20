# frozen_string_literal: true

module Ngqiniu
  # HTTP 协议相关
  module HTTP
    # HTTP 错误码
    module ErrorCode
      INVALID_ARGUMENT = -4
      INVALID_FILE = -3
      CANCELLED = -2
      NETWORK_ERROR = -1
      UNKNOWN_ERROR = 0
    end

    def self.client
      @client ||= if Config.default_faraday_connection.respond_to?(:call)
                    Client.new Config.default_faraday_connection.call
                  else
                    Client.new Config.default_faraday_connection
                  end
    end

    # HTTP 客户端
    class Client
      def initialize(faraday_connection)
        @faraday_connection = faraday_connection
      end

      %i[get head delete].each do |method|
        define_method(method) do |url = nil, params = nil, headers = nil|
          begin_time = Time.now
          faraday_response = @faraday_connection.public_send(method, url, params, headers)
          end_time = Time.now
          Response.new(faraday_response, duration: end_time - begin_time, address: nil)
        end
      end

      %i[post put patch].each do |method|
        define_method(method) do |url = nil, body = nil, headers = nil, &block|
          begin_time = Time.now
          faraday_response = @faraday_connection.public_send(method, url, body, headers, &block)
          end_time = Time.now
          Response.new(faraday_response, duration: end_time - begin_time, address: nil)
        end
      end
    end
  end
end
