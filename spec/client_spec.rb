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
    client = nil
    bucket = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      bucket = client.create_bucket("test-bucket-#{time_id}")
    end

    after :all do
      bucket.drop
    end

    it 'should get bucket domains' do
      expect(client.bucket('z0-bucket').domains).to include('z0-bucket.kodo-test.qiniu-solutions.com')
    end

    it 'should set / unset image for bucket' do
      expect(bucket.image).to be_nil
      begin
        bucket.set_image 'http://www.qiniu.com', source_host: 'z0-bucket.kodo-test.qiniu-solutions.com'
        expect(bucket.image.source_url).to eq('http://www.qiniu.com')
        expect(bucket.image.source_host).to eq('z0-bucket.kodo-test.qiniu-solutions.com')
      ensure
        bucket.unset_image
      end
    end

    it 'should update bucket acl' do
      expect(bucket).not_to be_private
      begin
        bucket.private!
        expect(bucket).to be_private
      ensure
        bucket.public!
        expect(bucket).not_to be_private
      end
    end
  end
end
