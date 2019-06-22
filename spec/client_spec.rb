# frozen_string_literal: true

RSpec.describe QiniuNg::Client do
  describe QiniuNg::Storage::BucketManager do
    it 'should get all bucket names' do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      expect(client.bucket_names).to include('z0-bucket', 'z1-bucket', 'na-bucket')
    end

    it 'should create / drop bucket' do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      bucket = client.create_bucket("test-bucket-#{time_id}")
      begin
        expect(client.bucket_names).to include(bucket.name)
      ensure
        client.drop_bucket(bucket.name)
      end
    end
  end

  describe QiniuNg::Storage::Bucket do
    it 'should get bucket domains' do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      expect(client.bucket('z0-bucket').domains).to include('z0-bucket.kodo-test.qiniu-solutions.com')
    end

    it 'should set / unset image for bucket' do
      bucket = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key).bucket('z0-bucket')
      begin
        bucket.set_image 'http://www.qiniu.com'
      ensure
        bucket.unset_image
      end
    end
  end
end
