# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    def self.client(auth: nil, auth_version: nil)
      faraday_connection = begin
        opts = Config.default_faraday_options
        opts = opts.call if opts.respond_to?(:call)
        Faraday.new(nil, opts) do |conn|
          conn.request :retry
          conn.request :qiniu_auth, auth: auth, version: auth_version
          conn.response :json, content_type: /\bjson$/
          conn.response :qiniu_raise_error
          conn.response :raise_error
          conn.headers.update(user_agent: "QiniuNg SDK v#{VERSION}")
          Config.default_faraday_config.call(conn)
        end
      end
      Client.new(faraday_connection, auth: auth, auth_version: auth_version)
    end

    # HTTP 客户端
    class Client
      def initialize(faraday_connection, auth: nil, auth_version: nil)
        @faraday_connection = faraday_connection
        @auth = auth
        @auth_version = auth_version
      end

      %i[get head delete].each do |method|
        define_method(method) do |url, params: nil, headers: {}, **options|
          begin_time = Time.now
          faraday_response = @faraday_connection.public_send(method, url, params, headers) do |req|
            req.options.update(options)
          end
          end_time = Time.now
          Response.new(faraday_response, duration: end_time - begin_time, address: nil)
        end
      end

      %i[post put patch].each do |method|
        define_method(method) do |url, params: nil, body: nil, headers: {}, **options|
          begin_time = Time.now
          headers = { content_type: 'application/x-www-form-urlencoded' }.merge(headers)
          faraday_response = @faraday_connection.public_send(method, url, body, headers) do |req|
            req.params.update(params) unless params.nil?
            req.options.update(options)
          end
          end_time = Time.now
          Response.new(faraday_response, duration: end_time - begin_time, address: nil)
        end
      end
    end
  end
end
