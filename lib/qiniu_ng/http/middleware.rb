# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    # 七牛 HTTP 中间件
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
            env[:request_headers][:authorization] = @auth.authorization_for_request(
              env[:url],
              version: @version,
              method: env[:method],
              content_type: env[:request_headers][:content_type],
              body: env[:request_body]
            )
          end
          @app.call(env)
        end
      end

      Faraday::Request.register_middleware qiniu_auth: -> { Auth }
    end
  end
end
