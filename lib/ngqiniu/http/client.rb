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

      Faraday::Connection::METHODS.each do |method|
        define_method(method) do |*args|
          begin_time = Time.now
          faraday_response = @faraday_connection.public_send(method, *args)
          end_time = Time.now
          Response.new(faraday_response, duration: end_time - begin_time, address: nil)
        end
      end
    end
  end
end
