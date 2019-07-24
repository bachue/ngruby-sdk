# frozen_string_literal: true

RSpec.describe QiniuNg::Storage::Uploader do
  http_client = nil
  bucket = nil
  entry = nil

  before :all do
    auth = QiniuNg::Auth.new(access_key: access_key, secret_key: secret_key)
    http_client = QiniuNg::HTTP.client(auth: auth, auth_version: 1)
    bucket = QiniuNg::Storage::BucketManager.new(http_client, nil, auth).bucket('z0-bucket', zone: QiniuNg::Zone.huadong)
  end

  after :each do
    QiniuNg::Config.default_domains_manager.unfreeze_all!
  end

  describe QiniuNg::Storage::Uploader::FormUploader do
    uploader = nil
    before :all do
      uploader = QiniuNg::Storage::Uploader::FormUploader.new(bucket, http_client)
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
        response = head(entry.download_url.refresh)
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
                                             upload_token: bucket.upload_token(key_prefix: 'test-image-'))
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        response = head(entry.download_url.refresh)
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

    describe do
      before :all do
        WebMock.enable!
      end

      after :all do
        WebMock.disable!
      end

      after :each do
        WebMock.reset!
      end

      entry = nil
      path = nil

      before :each do
        entry = bucket.entry('test-image.png')
        path = create_temp_file(kilo_size: 10)
      end

      after :each do
        File.unlink(path)
      end

      it 'should switch to backup url, and raise error if all urls are exhausted' do
        stub_request(:post, 'http://upload.qiniup.com/').to_timeout
        stub_request(:post, 'http://up.qiniup.com')
          .to_return(headers: { 'Content-Type': 'text/plain' },
                     body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
        stub_request(:post, 'http://upload.qbox.me')
          .to_return(status: 500, headers: { 'Content-Type': 'text/plain' }, body: {}.to_json)
        stub_request(:post, 'http://up.qbox.me')
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token,
                                           params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                           meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        assert_requested(:post, 'http://upload.qiniup.com', times: 4)
        assert_requested(:post, 'http://up.qiniup.com', times: 4)
        assert_requested(:post, 'http://upload.qbox.me', times: 4)
        assert_requested(:post, 'http://up.qbox.me', times: 1)

        WebMock.reset!

        stub_request(:post, 'http://up.qbox.me').to_timeout
        expect do
          result = uploader.sync_upload_file(path, upload_token: entry.upload_token)
        end.to raise_error(Faraday::ConnectionFailed)
        assert_requested(:post, 'http://up.qbox.me', times: 4)

        WebMock.reset!

        expect do
          result = uploader.sync_upload_file(path, upload_token: entry.upload_token)
        end.to raise_error(QiniuNg::HTTP::NoURLAvailable)
      end

      it 'should validate the checksum' do
        stub_request(:post, 'http://upload.qiniup.com/')
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
        stub_request(:post, "http://rs.qiniu.com/delete/#{Base64.urlsafe_encode64("#{bucket.name}:#{entry.key}")}")
          .to_return(headers: { 'Content-Type': 'application/json' }, body: {}.to_json)

        expect do
          io = StringIO.new(File.binread(path))
          uploader.sync_upload_stream(io, upload_token: entry.upload_token,
                                          crc32: uploader.send(:crc32_of_file, path),
                                          etag: 'def')
        end.to raise_error(QiniuNg::Storage::Uploader::ChecksumError)

        stub_request(:post, 'http://upload.qiniup.com/')
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)

        io = StringIO.new(File.binread(path))
        result = uploader.sync_upload_stream(io, upload_token: entry.upload_token,
                                                 crc32: uploader.send(:crc32_of_file, path),
                                                 etag: uploader.send(:etag_of_file, path))
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end
    end
  end

  describe QiniuNg::Storage::Uploader::ResumableUploader do
    uploader = nil
    before :all do
      uploader = QiniuNg::Storage::Uploader::ResumableUploader.new(bucket, http_client)
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
        response = head(entry.download_url.refresh)
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
    #                                          upload_token: bucket.upload_token(key_prefix: '15mb-'))
    #     expect(result.hash).not_to be_empty
    #     expect(result.key).to eq entry.key
    #     response = head(entry.download_url.refresh)
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

    describe do
      entry = nil
      encoded_key = nil
      path = nil

      before :all do
        WebMock.enable!
      end

      after :all do
        WebMock.disable!
      end

      before :each do
        entry = bucket.entry('test-data')
        encoded_key = Base64.urlsafe_encode64(entry.key)
        path = create_temp_file(kilo_size: 5 * 1024)
      end

      after :each do
        File.unlink(path)
        WebMock.reset!
      end

      it 'should record the progress' do
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_raise(RuntimeError)
        expect do
          uploader.sync_upload_file(path,
                                    upload_token: entry.upload_token, disable_checksum: true,
                                    recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(RuntimeError)

        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token, disable_checksum: true,
                                           recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end

      it 'should record the progress' do
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_raise(RuntimeError)
        expect do
          uploader.sync_upload_file(path,
                                    upload_token: entry.upload_token, disable_checksum: true,
                                    recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(RuntimeError)

        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token, disable_checksum: true,
                                           recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
      end

      it 'should switch to backup url' do
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads").to_timeout
        stub_request(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        stub_request(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        result = uploader.sync_upload_file(path,
                                           upload_token: entry.upload_token, disable_checksum: true,
                                           params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                           meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        expect(result.hash).not_to be_empty
        expect(result.key).to eq entry.key
        assert_requested(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads", times: 4)
        assert_requested(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads", times: 1)
        assert_requested(:put, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1", times: 1)
        assert_requested(:put, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2", times: 1)
        assert_requested(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc", times: 1)
      end

      it 'could exhaust all urls and raise error' do
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads").to_timeout
        stub_request(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1").to_timeout
        stub_request(:put, "http://upload.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        stub_request(:put, "http://upload.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2").to_timeout
        stub_request(:put, "http://up.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        stub_request(:post, "http://up.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: '{')
        expect do
          uploader.sync_upload_file(path,
                                    upload_token: entry.upload_token, disable_checksum: true,
                                    params: { param_key1: 'param_value1', param_key2: 'param_value2' },
                                    meta: { meta_key1: 'meta_value1', meta_key2: 'meta_value2' })
        end.to raise_error(Faraday::ParsingError)
        assert_requested(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads", times: 4)
        assert_requested(:post, "http://up.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads", times: 1)
        assert_requested(:put, "http://upload.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1", times: 1)
        assert_requested(:put, "http://upload.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2", times: 4)
        assert_requested(:put, "http://up.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2", times: 1)
        assert_requested(:post, "http://up.qbox.me/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc", times: 4)
      end

      it 'should validate the checksum' do
        etags = [
          QiniuNg::Etag.from_data(File.binread(path, QiniuNg::BLOCK_SIZE)),
          QiniuNg::Etag.from_data(File.binread(path, QiniuNg::BLOCK_SIZE, QiniuNg::BLOCK_SIZE))
        ]
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { uploadId: 'abc' }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '123' }.to_json)
        expect do
          uploader.sync_upload_file(path, upload_token: entry.upload_token,
                                          recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(QiniuNg::Storage::Uploader::ChecksumError)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: etags[0] }.to_json)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: '456' }.to_json)
        expect do
          uploader.sync_upload_file(path, upload_token: entry.upload_token,
                                          recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(QiniuNg::Storage::Uploader::ChecksumError)
        stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { etag: etags[1] }.to_json)
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: 'fakehash', key: entry.key }.to_json)
        stub_request(:post, "http://rs.qiniu.com/delete/#{Base64.urlsafe_encode64("#{bucket.name}:#{entry.key}")}")
          .to_return(headers: { 'Content-Type': 'application/json' }, body: {}.to_json)
        expect do
          uploader.sync_upload_file(path, upload_token: entry.upload_token,
                                          recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
        end.to raise_error(QiniuNg::Storage::Uploader::ChecksumError)
        stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
          .to_return(headers: { 'Content-Type': 'application/json' },
                     body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
        uploader.sync_upload_file(path, upload_token: entry.upload_token,
                                        recorder: QiniuNg::Storage::Recorder::FileRecorder.new)
      end
    end
  end

  describe QiniuNg::Storage::Uploader do
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

    it 'should use form uploader for small file' do
      entry = bucket.entry('test-data')
      path = create_temp_file(kilo_size: 4 * 1024)
      stub_request(:post, 'http://upload.qiniup.com')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
      begin
        bucket.upload(filepath: path, upload_token: entry.upload_token)
      ensure
        File.unlink(path)
      end
    end

    it 'should use resumable uploader for big file' do
      entry = bucket.entry('test-data')
      encoded_key = Base64.urlsafe_encode64(entry.key)
      path = create_temp_file(kilo_size: 5 * 1024)
      stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { uploadId: 'abc' }.to_json)
      stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { etag: '123' }.to_json)
      stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/2")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { etag: '456' }.to_json)
      stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { hash: 'fakehash', key: entry.key }.to_json)
      begin
        bucket.upload(filepath: path, upload_token: entry.upload_token, disable_checksum: true)
      ensure
        File.unlink(path)
      end
    end

    it 'should use resumable uploader by force' do
      entry = bucket.entry('test-data')
      encoded_key = Base64.urlsafe_encode64(entry.key)
      path = create_temp_file(kilo_size: 1 * 1024)
      stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { uploadId: 'abc' }.to_json)
      stub_request(:put, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc/1")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { etag: '123' }.to_json)
      stub_request(:post, "http://upload.qiniup.com/buckets/z0-bucket/objects/#{encoded_key}/uploads/abc")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { hash: 'fakehash', key: entry.key }.to_json)
      begin
        bucket.upload(filepath: path, upload_token: entry.upload_token,
                      resumable_policy: :always, disable_checksum: true)
      ensure
        File.unlink(path)
      end
    end

    it 'should use form uploader by force' do
      entry = bucket.entry('test-data')
      path = create_temp_file(kilo_size: 10 * 1024)
      stub_request(:post, 'http://upload.qiniup.com')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { hash: QiniuNg::Etag.from_file_path(path), key: entry.key }.to_json)
      begin
        bucket.upload(filepath: path, upload_token: entry.upload_token, resumable_policy: :never)
      ensure
        File.unlink(path)
      end
    end
  end
end
