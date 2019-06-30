# frozen_string_literal: true

RSpec.describe QiniuNg::Storage::Uploader do
  auth = nil
  http_client = nil
  bucket = nil
  entry = nil

  before :all do
    auth = QiniuNg::Auth.new(access_key: access_key, secret_key: secret_key)
    http_client = QiniuNg::HTTP.client(auth: auth, auth_version: 1)
    bucket = QiniuNg::Storage::BucketManager.new(http_client, auth).bucket('z0-bucket')
  end

  describe QiniuNg::Storage::Uploader::FormUploader do
    uploader = nil
    before :all do
      uploader = QiniuNg::Storage::Uploader::FormUploader.new(bucket, http_client, auth)
    end

    it 'should upload file directly' do
      entry = bucket.entry("test-image-#{Time.now.usec}.png")
      path = temp_file_from_url('https://www.baidu.com/img/bd_logo1.png')
      begin
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                           meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        response = head(entry.download_url.public + "?t=#{Time.now.usec}")
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

    it 'should upload stream' do
      entry = bucket.entry("test-image-#{Time.now.usec}.png")
      path = temp_file_from_url('https://www.baidu.com/img/bd_logo1.png')
      stream = File.open(path, 'rb')
      begin
        result = uploader.sync_upload_stream(stream,
                                             key: entry.key,
                                             upload_token: bucket.upload_token_for_key_prefix('test-image-'))
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        response = head(entry.download_url.public + "?t=#{Time.now.usec}")
        expect(response).to be_success
        expect(response.headers[:content_type]).to eq 'image/png'
        expect(response.headers[:content_length]).to eq File.size(path).to_s
        expect(response.headers[:etag]).to eq %("#{result.hash}")
      ensure
        stream.close
        entry.try_delete
        File.unlink(path)
      end
    end

    describe 'auto retry' do
      before :all do
        bucket.zone
        WebMock.enable!
      end

      after :all do
        WebMock.disable!
      end

      after :each do
        WebMock.reset!
      end

      it 'should switch to backup url' do
        entry = bucket.entry("test-image-#{Time.now.usec}.png")
        path = create_temp_file(kilo_size: 10)

        stub_request(:post, 'http://up.qiniu.com/').to_timeout
        stub_request(:post, 'http://upload.qiniu.com')
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        begin
          result = uploader.sync_upload_file(path,
                                             upload_token: entry.upload_token,
                                             params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                             meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
          expect(result.hash).not_to be_empty
          expect(result.key).to eq entry.key
        ensure
          File.unlink(path)
        end
      end
    end
  end

  describe QiniuNg::Storage::Uploader::ResumableUploader do
    uploader = nil
    before :all do
      uploader = QiniuNg::Storage::Uploader::ResumableUploader.new(bucket, http_client, auth)
    end

    it 'should upload file directly' do
      entry = bucket.entry("9mb-#{Time.now.usec}")
      path = create_temp_file(kilo_size: 9 * 1024)
      begin
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                           meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        response = head(entry.download_url.public + "?t=#{Time.now.usec}")
        expect(response).to be_success
        expect(response.headers[:content_type]).to eq 'application/octet-stream'
        expect(response.headers[:content_length]).to eq File.size(path).to_s
        expect(response.headers[:etag]).to eq %("#{result.hash}")
        expect(response.headers['x-qn-meta-meta-key1']).to eq 'meta_value1'
        expect(response.headers['x-qn-meta-meta-key2']).to eq 'meta_value2'
      ensure
        entry.try_delete
        File.unlink(path)
      end
    end

    # it 'should upload stream' do
    #   entry = bucket.entry("15mb-#{Time.now.usec}")
    #   path = create_temp_file(kilo_size: 15 * 1024)
    #   stream = File.open(path, 'rb')
    #   begin
    #     result = uploader.sync_upload_stream(stream,
    #                                          key: entry.key,
    #                                          upload_token: bucket.upload_token_for_key_prefix('15mb-'))
    #     expect(result.hash).not_to be_empty
    #     expect(result.key).to eq entry.key
    #     response = head(entry.download_url.public + "?t=#{Time.now.usec}")
    #     expect(response).to be_success
    #     expect(response.headers[:content_type]).to eq 'application/octet-stream'
    #     expect(response.headers[:content_length]).to eq File.size(path).to_s
    #     expect(response.headers[:etag]).to eq %("#{result.hash}")
    #   ensure
    #     stream.close
    #     entry.try_delete
    #     File.unlink(path)
    #   end
    # end

    describe 'features' do
      entry = nil
      encoded_key = nil
      path = nil

      before :all do
        bucket.zone

        WebMock.enable!
      end

      after :all do
        WebMock.disable!
      end

      before :each do
        entry = bucket.entry('test-image.png')
        encoded_key = Base64.urlsafe_encode64(entry.key)
        path = create_temp_file(kilo_size: 5 * 1024)
      end

      after :each do
        File.unlink(path)
        WebMock.reset!
      end

      it 'should record the progress' do
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_raise(RuntimeError)
        expect do
          uploader.sync_upload_file(path,
                                    upload_token: entry.upload_token,
                                    recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(RuntimeError)

        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end

      it 'should record the progress' do
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_raise(RuntimeError)
        expect do
          uploader.sync_upload_file(path,
                                    upload_token: entry.upload_token,
                                    recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(RuntimeError)

        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end

      it 'should switch to backup url' do
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads").to_timeout
        stub_request(:post, "http://upload.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1").to_timeout
        stub_request(:put, "http://upload.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2").to_timeout
        stub_request(:put, "http://upload.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        stub_request(:post, "http://up.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc").to_timeout
        stub_request(:post, "http://upload.qiniu.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                           meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end
    end
  end
end
