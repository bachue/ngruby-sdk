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
          conn.headers.update(user_agent: "QiniuNg SDK v#{VERSION}/#{RUBY_DESCRIPTION}")
          Config.default_faraday_config.call(conn)
        end
      end
      Client.new(faraday_connection, auth: auth, auth_version: auth_version)
    end

    class NeedToRetry < Faraday::Error
    end

    RETRYABLE_EXCEPTIONS = [*Faraday::Request::Retry::DEFAULT_EXCEPTIONS, NeedToRetry,
                            Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError].freeze
    IDEMPOTENT_METHODS = %i[delete get head options put].freeze

    # HTTP 客户端
    class Client
      def initialize(faraday_connection, auth: nil, auth_version: nil)
        @faraday_connection = faraday_connection
        @auth = auth
        @auth_version = auth_version
      end

      # rubocop:disable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters
      %i[get head delete].each do |method|
        define_method(method) do |path, urls, params: nil, headers: {}, idempotent: nil,
                                              retries: Config.default_http_request_retries,
                                              retry_delay: Config.default_http_request_retry_delay,
                                              retry_if: ->(*_args) { false },
                                              **options|
          http_request_with_retry(method, path.to_s, urls, nil, retries, retry_delay, retry_if, idempotent) do |url|
            @faraday_connection.public_send(method, url, params, headers) do |req|
              req.options.update(options)
            end
          end
        end
      end

      %i[post put patch].each do |method|
        define_method(method) do |path, urls, params: nil, body: nil, headers: {}, idempotent: nil,
                                              retries: Config.default_http_request_retries,
                                              retry_delay: Config.default_http_request_retry_delay,
                                              retry_if: ->(*_args) { false },
                                              **options|
          http_request_with_retry(method, path.to_s, urls, body, retries, retry_delay, retry_if, idempotent) do |url|
            headers = { content_type: 'application/x-www-form-urlencoded' }.merge(headers)
            @faraday_connection.public_send(method, url, body, headers) do |req|
              req.params.update(params) unless params.nil?
              req.options.update(options)
            end
          end
        end
      end
      # rubocop:enable Layout/MultilineBlockLayout, Layout/SpaceAroundBlockParameters

      private

      def http_request_with_retry(method, path, urls, body, retries, retry_delay, retry_if, idempotent)
        raise ArgumentError, 'urls must not be nil or empty' if urls.nil? || urls.empty?

        urls = [urls] unless urls.is_a?(Array)
        url = join_url(urls.shift, path)
        retried = 0
        begin
          begin_time = Time.now
          resp = yield url
          end_time = Time.now
          raise NeedToRetry if retry_if.call(resp.status, resp.headers, resp.body, nil)

          Response.new(resp, duration: end_time - begin_time, address: nil)
        rescue Faraday::Error => e
          raise unless retryable?(e, method, retry_if, idempotent)

          if retried < retries
            retried += 1
            rewind_files(body)
            sleep(retry_delay) if retry_delay.positive?
            retry
          end
          raise if urls.empty?

          url = join_url(urls.shift, path)
          retried = 0
          retry
        end
      end

      def join_url(url_prefix, path)
        url = url_prefix
        url += if url.end_with?('/') && path.start_with?('/')
                 path[1..-1]
               elsif url.end_with?('/') || path.start_with?('/')
                 path
               else
                 '/' + path
               end
        url
      end

      def retryable?(error, method, retry_if, idempotent)
        idempotent = IDEMPOTENT_METHODS.include?(method.to_sym) if idempotent.nil?
        return true if idempotent && RETRYABLE_EXCEPTIONS.any? do |err_class|
                         if err_class.is_a?(Module)
                           error.is_a?(err_class)
                         else
                           error.class.to_s == err_class.to_s
                         end
                       end
        return true if error.is_a?(NeedToRetry)
        return false if error.response.nil?

        if error.response.is_a?(Hash)
          retry_if.call(error.response[:status], error.response[:headers], error.response[:body], error)
        else
          retry_if.call(error.response.status, error.response.headers, error.response.body, error)
        end
      end

      def rewind_files(body)
        return if body.nil?
        return unless body.is_a?(Hash)

        body.each do |_, value|
          value.rewind if value&.is_a?(UploadIO)
        end
      end
    end
  end
end
