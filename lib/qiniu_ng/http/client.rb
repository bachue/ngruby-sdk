# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    def self.client(auth: nil, auth_version: nil)
      faraday_connection = begin
        opts = Config.default_faraday_options
        opts = opts.call if opts.respond_to?(:call)
        Faraday.new(nil, opts) do |conn|
          conn.request :multipart
          conn.request :qiniu_auth, auth: auth, version: auth_version
          conn.response :json, content_type: /\bjson$/
          conn.response :raise_error
          conn.response :qiniu_raise_error
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
        define_method(method) do |url, params: nil, headers: {}, backup_urls: [], **options|
          begin
            begin_time = Time.now
            faraday_response = @faraday_connection.public_send(method, url, params, headers) do |req|
              req.options.update(options)
            end
            end_time = Time.now
            Response.new(faraday_response, duration: end_time - begin_time, address: nil)
          rescue Faraday::Error => e
            raise unless retryable?(e)

            next_url = backup_urls.shift
            raise if next_url.nil?

            next_url += '/' unless next_url.end_with?('/')
            url.sub!(%r{^https?://[^/]+}, next_url)
            retry
          end
        end
      end

      %i[post put patch].each do |method|
        define_method(method) do |url, params: nil, body: nil, headers: {}, backup_urls: [], **options|
          begin
            begin_time = Time.now
            headers = { content_type: 'application/x-www-form-urlencoded' }.merge(headers)
            faraday_response = @faraday_connection.public_send(method, url, body, headers) do |req|
              req.params.update(params) unless params.nil?
              req.options.update(options)
            end
            end_time = Time.now
            Response.new(faraday_response, duration: end_time - begin_time, address: nil)
          rescue Faraday::Error => e
            raise unless retryable?(e)

            next_url = backup_urls.shift
            raise if next_url.nil?

            next_url += '/' unless next_url.end_with?('/')
            url = url.sub(%r{^https?://[^/]+/}, next_url)
            retry
          end
        end
      end

      private

      def retryable?(error)
        [Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError].each do |err_class|
          return true if error.is_a?(err_class)
        end

        status = error.response&.dig(:status)
        ((500...600).include?(status) && status != 579) || status == 996 if status
      end
    end
  end
end
