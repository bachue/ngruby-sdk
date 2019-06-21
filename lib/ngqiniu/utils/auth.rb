# frozen_string_literal: true

require 'openssl'
require 'base64'

module Ngqiniu
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

      def sign_request(url, content_type:, body: nil)
        form_mime = 'application/x-www-form-urlencoded'
        uri = URI(url)
        data_to_sign = uri.path.encode('UTF-8')
        data_to_sign += '?' + uri.query.encode('UTF-8') unless uri.query.nil?
        data_to_sign += "\n"
        data_to_sign += body if !body.nil? && form_mime.casecmp?(content_type)
        sign(data_to_sign)
      end

      def callback_valid?(original_authorization, url, content_type:, body: nil)
        original_authorization == "QBox #{sign_request(url, body: body, content_type: content_type)}"
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
        deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        sign_download_url_with_deadline(base_url, deadline: deadline)
      end

      private

      def hmac_digest(data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), @secret_key, data)
      end
    end
  end
end
