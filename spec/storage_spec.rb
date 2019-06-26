# frozen_string_literal: true

RSpec.describe QiniuNg::Storage do
  describe QiniuNg::Storage::UploadToken do
    it 'should create upload_token from upload_policy, or from token' do
      dummy_access_key = 'abcdefghklmnopq'
      dummy_secret_key = '1234567890'
      dummy_auth = QiniuNg::Auth.new(access_key: dummy_access_key, secret_key: dummy_secret_key)
      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test', key: 'filename')
      policy.set_token_lifetime(seconds: 30).detect_mime!.infrequent_storage!.limit_content_type('video/*')
      upload_token = QiniuNg::Storage::UploadToken.from_policy(policy, dummy_auth)
      expect(upload_token.policy).to eq policy
      expect(upload_token.token).to be_a String

      upload_token2 = QiniuNg::Storage::UploadToken.from_token(upload_token.token)
      expect(upload_token2.token).to eq upload_token.token
      expect(upload_token2.policy).to eq policy
    end
  end
end
