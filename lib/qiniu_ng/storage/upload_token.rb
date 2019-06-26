# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛上传凭证
    class UploadToken
      def initialize(auth: nil, upload_policy: nil, upload_token: nil)
        raise ArgumentError unless (auth.nil? && upload_policy.nil?) || upload_token.nil?

        @auth = auth
        @policy = upload_policy
        @token = upload_token
      end

      def self.from_policy(upload_policy, auth)
        new(auth: auth, upload_policy: upload_policy)
      end

      def self.from_token(upload_token)
        new(upload_token: upload_token)
      end

      def policy
        @policy ||= Model::UploadPolicy.from_json(Base64.urlsafe_decode64(@token.split(':').last))
      end

      def token
        @token ||= @auth.sign_upload_policy(@policy)
      end
      alias to_s token
    end
  end
end
