# frozen_string_literal: true

RSpec.describe QiniuNg::Storage::Uploader do
  describe QiniuNg::Storage::Uploader::FormUploader do
    auth = nil
    entry = nil
    uploader = nil
    before :all do
      auth = QiniuNg::Auth.new(access_key: access_key, secret_key: secret_key)
      http_client = QiniuNg::HTTP.client(auth: auth, auth_version: 1)
      bucket = QiniuNg::Storage::BucketManager.new(http_client, auth).bucket('z0-bucket')
      entry = bucket.entry("test-image-#{Time.now.usec}.png")
      uploader = QiniuNg::Storage::Uploader::FormUploader.new(bucket, http_client, auth)
    end

    it 'should upload file directly' do
      path = temp_file_from_url('https://www.baidu.com/img/bd_logo1.png')
      begin
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           params: { param_key1: :param_value1, param_key2: :param_value2 },
                                           meta: { meta_key1: :meta_value1, meta_key2: :meta_value2 })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        response = Faraday.get(entry.download_url.public + "?t=#{Time.now.usec}")
        expect(response).to be_success
        expect(response.headers[:content_type]).to eq 'image/png'
        expect(response.headers[:content_length]).to eq File.size(path).to_s
        expect(response.headers[:etag]).to eq %("#{result.hash}")
        expect(response.headers['x-qn-meta-meta_key1']).to eq 'meta_value1'
        expect(response.headers['x-qn-meta-meta_key2']).to eq 'meta_value2'
      ensure
        entry.try_delete
        File.unlink(path)
      end
    end
  end
end
