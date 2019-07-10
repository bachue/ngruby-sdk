# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛上传凭证
    #
    # 该类可用于为上传策略生成上传凭证，或是从上传凭证中解析出上传策略
    class UploadToken
      # @!visibility private
      def initialize(auth: nil, upload_policy: nil, upload_token: nil)
        raise ArgumentError unless (auth.nil? && upload_policy.nil?) || upload_token.nil?

        @auth = auth
        @policy = upload_policy.freeze
        @token = upload_token.freeze
      end

      # 通过上传策略中生成上传凭证
      #
      # @param [QiniuNg::Storage::Model::UploadPolicy] upload_policy 上传策略
      # @param [QiniuNg::Auth] auth 七牛 AccessKey，SecretKey
      #
      # @return [QiniuNg::Storage::UploadToken] 获取上传凭证
      def self.from_policy(upload_policy, auth)
        new(auth: auth, upload_policy: upload_policy)
      end

      # 解析上传凭证
      #
      # @param [String] upload_token 上传凭证字符串
      #
      # @return [QiniuNg::Storage::UploadToken] 获取上传凭证
      def self.from_token(upload_token)
        new(upload_token: upload_token)
      end

      # 获取上传策略
      #
      # @return [QiniuNg::Storage::Model::UploadPolicy] 获取上传策略
      def policy
        @policy ||= Model::UploadPolicy.from_json(Base64.urlsafe_decode64(@token.split(':').last)).freeze
      end

      # 生成上传凭证
      #
      # @return [String] 生成上传凭证
      def token
        @token ||= @auth.sign_upload_policy(@policy).freeze
      end
      alias to_s token
    end
  end
end
