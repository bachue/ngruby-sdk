# frozen_string_literal: true

require 'openssl'
require 'base64'

module QiniuNg
  module Utils
    # 七牛签名计算实用工具
    class Auth
      # @!visibility private
      attr_reader :access_key

      # 创建新的七牛签名计算器
      #
      # @example
      #   auth = QiniuNg::Auth.new(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #
      # @param [String] access_key 七牛 Access Key
      # @param [String] secret_key 七牛 Secret Key
      # @return [QiniuNg::Auth] 返回新建的七牛签名计算器
      def initialize(access_key:, secret_key:)
        @access_key = access_key.freeze
        @secret_key = secret_key.freeze
      end

      # @!visibility private
      def sign(data)
        "#{@access_key}:#{Base64.urlsafe_encode64(hmac_digest(data.encode('UTF-8')))}"
      end

      # @!visibility private
      def sign_with_data(data)
        encoded_data = Base64.urlsafe_encode64(data)
        "#{sign(encoded_data)}:#{encoded_data}"
      end

      # @!visibility private
      def sign_request(url, version: 1, method: 'GET', content_type:, body: nil)
        case version
        when 1 then sign_request_v1(url, content_type: content_type, body: body)
        when 2 then sign_request_v2(url, method: method, content_type: content_type, body: body)
        else raise NotImplementedError
        end
      end

      # @!visibility private
      def authorization_for_request(url, version: 1, method: 'GET', content_type:, body: nil)
        case version
        when 1 then 'QBox ' + sign_request_v1(url, content_type: content_type, body: body)
        when 2 then 'Qiniu ' + sign_request_v2(url, method: method, content_type: content_type, body: body)
        else raise NotImplementedError
        end
      end

      # @!visibility private
      def sign_request_v1(url, content_type:, body: nil)
        uri = URI(url)
        data_to_sign = uri.path.encode('UTF-8')
        data_to_sign += '?' + uri.query.encode('UTF-8') unless uri.query.nil?
        data_to_sign += "\n"
        data_to_sign += body if inc_body_v1?(content_type, body)
        sign(data_to_sign)
      end

      # @!visibility private
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

      # 判定上传完毕后的回调请求是否是合法的
      #
      # @param [String] original 来自七牛回调请求中的 Authorization Header
      # @param [String] url 被回调的服务器访问地址
      # @param [String] method 回调请求的方法
      # @param [String] content_type 回调请求的 Content-Type Header
      # @param [String] body 回调请求的数据
      # @return [Boolean] 是否合法
      def callback_valid?(original, url, method: 'POST', content_type:, body: nil)
        expected = authorization_for_request(url, version: 1, method: method, body: body, content_type: content_type)
        original == expected
      end

      # @!visibility private
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

      # @!visibility private
      def sign_download_url_with_lifetime(base_url, lifetime:)
        lifetime = Duration.new(lifetime) if lifetime.is_a?(Hash)
        deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        sign_download_url_with_deadline(base_url, deadline: deadline)
      end

      # @!visibility private
      def sign_upload_policy(upload_policy)
        sign_with_data(Config.default_json_marshaler.call(upload_policy))
      end

      # @!visibility private
      def inspect
        %(#<#{self.class.name} @access_key=#{@access_key.inspect} @secret_key=CENSORED>)
      end

      private

      def hmac_digest(data)
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), @secret_key, data)
      end

      def inc_body_v1?(content_type, body)
        form_mime = 'application/x-www-form-urlencoded'
        !body.nil? && !content_type.nil? && form_mime.casecmp(content_type).zero?
      end

      def inc_body_v2?(content_type, body)
        form_mime = 'application/x-www-form-urlencoded'
        json_mime = 'application/json'
        !body.nil? && !content_type.nil? &&
          (form_mime.casecmp(content_type).zero? || json_mime.casecmp(content_type).zero?)
      end
    end
  end
end
