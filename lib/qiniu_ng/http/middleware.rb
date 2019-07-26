# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    # @!visibility private
    module Middleware
      # 七牛请求签名中间件
      class Auth < Faraday::Middleware
        def initialize(app, auth:, version:)
          super(app)
          @auth = auth
          @version = version
        end

        def call(env)
          unless @auth.nil? || @version.nil?
            env.request_headers[:authorization] ||= @auth.authorization_for_request(
              env.url,
              version: @version,
              method: env.method,
              content_type: env.request_headers[:content_type],
              body: env[:body]
            )
          end
          @app.call(env)
        end
      end

      # 七牛 HTTP 错误处理中间件
      class RaiseError < Faraday::Response::Middleware
        def on_complete(env)
          case env[:status]
          when 419
            raise UserDisabledError, response_values(env)
          when 573
            raise OutOfLimitError, response_values(env)
          when 579
            raise CallbackFailed, response_values(env)
          when 599
            raise FunctionError, response_values(env)
          when 500..600
            raise ServerRetryableError, response_values(env)
          when 608
            raise FileModified, response_values(env)
          when 612
            raise ResourceNotFound, response_values(env)
          when 614
            raise ResourceExists, response_values(env)
          when 619
            raise NoData, response_values(env)
          when 630
            raise TooManyBuckets, response_values(env)
          when 631
            raise BucketNotFound, response_values(env)
          when 640
            raise InvalidMarker, response_values(env)
          when 701
            raise InvalidContext, response_values(env)
          when 600..1000
            raise ServerError, response_values(env)
          end
        end

        private

        def response_values(env)
          { status: env.status, headers: env.response_headers, body: env.body }
        end
      end

      Faraday::Request.register_middleware qiniu_auth: -> { Auth }
      Faraday::Response.register_middleware qiniu_raise_error: -> { RaiseError }
    end
  end
end
