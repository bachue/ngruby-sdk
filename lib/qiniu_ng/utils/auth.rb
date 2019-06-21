# frozen_string_literal: true

require 'openssl'
require 'base64'

module QiniuNg
  module Utils
    # 七牛认证相关
    class Auth
      attr_reader :access_key

      def initialize(access_key:, secret_key:)
        @access_key = access_key
        @secret_key = secret_key
      end

      def sign(data)
        "#{@access_key}:#{Base64.urlsafe_encode64(hmac_digest(data.encode('UTF-8')))}"
      end

      def sign_with_data(data)
        encoded_data = Base64.urlsafe_encode64(data)
        "#{sign(encoded_data)}:#{encoded_data}"
      end

      def sign_request(url, version: 1, method: 'GET', content_type:, body: nil)
        case version
        when 1 then sign_request_v1(url, content_type: content_type, body: body)
        when 2 then sign_request_v2(url, method: method, content_type: content_type, body: body)
        else raise NotImplementedError
        end
      end

      def authorization_for_request(url, version: 1, method: 'GET', content_type:, body: nil)
        case version
        when 1 then 'QBox ' + sign_request_v1(url, content_type: content_type, body: body)
        when 2 then 'Qiniu ' + sign_request_v2(url, method: method, content_type: content_type, body: body)
        else raise NotImplementedError
        end
      end

      def sign_request_v1(url, content_type:, body: nil)
        uri = URI(url)
        data_to_sign = uri.path.encode('UTF-8')
        data_to_sign += '?' + uri.query.encode('UTF-8') unless uri.query.nil?
        data_to_sign += "\n"
        data_to_sign += body if inc_body_v1?(content_type, body)
        sign(data_to_sign)
      end

      def sign_request_v2(url, method: 'GET', content_type:, body: nil)
        uri = URI(url)
        data_to_sign = "#{method.upcase} #{uri.path.encode('UTF-8')}"
        data_to_sign += '?' + uri.query.encode('UTF-8') unless uri.query.nil?
        data_to_sign += "\nHost: #{uri.host}"
        data_to_sign += ":#{uri.port}" if uri.port != uri.default_port
        data_to_sign += "\n"
        data_to_sign += "Content-Type: #{content_type}\n" unless content_type.nil? || content_type.empty?
        data_to_sign += "\n"
        data_to_sign += body if inc_body_v2?(content_type, body)
        sign(data_to_sign)
      end

      def callback_valid?(original, url, method: 'POST', content_type:, body: nil)
        expected = authorization_for_request(url, version: 1, method: method, body: body, content_type: content_type)
        original == expected
      end

      def sign_download_url_with_deadline(base_url, deadline:)
        url = base_url
        url += if url.include?('?')
                 '&e='
               else
                 '?e='
               end
        url += deadline.to_i.to_s
        token = sign(url.encode('UTF-8'))
        url += '&token=' + token
        url
      end

      def sign_download_url_with_lifetime(base_url, lifetime:)
        lifetime = Duration.new(lifetime) if lifetime.is_a?(Hash)
        deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        sign_download_url_with_deadline(base_url, deadline: deadline)
      end

      private

      def hmac_digest(data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), @secret_key, data)
      end

      def inc_body_v1?(content_type, body)
        form_mime = 'application/x-www-form-urlencoded'
        !body.nil? && !content_type.nil? && form_mime.casecmp?(content_type)
      end

      def inc_body_v2?(content_type, body)
        form_mime = 'application/x-www-form-urlencoded'
        json_mime = 'application/json'
        !body.nil? && !content_type.nil? && (form_mime.casecmp?(content_type) || json_mime.casecmp?(content_type))
      end
    end
  end
end
