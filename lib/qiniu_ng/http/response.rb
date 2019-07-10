# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module HTTP
    # @!visibility private
    class Response
      extend Forwardable

      def initialize(resp, address:, duration:)
        @faraday_response = resp
        @address = address
        @duration = duration
      end

      # 回复状态码
      def status_code
        @faraday_response.status
      end

      # 七牛日志扩展头
      def req_id
        @faraday_response.headers['X-ReqId']&.strip
      end

      # 七牛日志扩展头
      def xlog
        @faraday_response.headers['X-Log']&.strip
      end

      # cdn日志扩展头
      def xvia
        @faraday_response.headers['X-Via'] || @faraday_response.headers['X-Px'] || @faraday_response.headers['Fw-Via']
      end

      # 错误信息
      def error
        @faraday_response.body['error'] if @faraday_response.status >= 400
      end

      # 是否是服务器端错误
      def server_error?
        status = @faraday_response.status
        (status >= 500 && status < 600 && status != 579) || status == 996
      end

      # 请求消耗时间，单位秒
      attr_reader :duration

      # 服务器IP
      attr_reader :address

      def_delegators :@faraday_response, :env, :body, :finish, :finished?, :headers, :reason_phrase, :status, :success?
    end
  end
end
