# frozen_string_literal: true

RSpec.describe QiniuNg::HTTP do
  describe QiniuNg::HTTP::Client do
    it 'should create qiniu_ng http response for faraday response' do
      resp = QiniuNg::HTTP.client(domains_manager: QiniuNg::HTTP::DomainsManager.new)
                          .get('/v1/query', 'https://uc.qbox.me', params: { ak: access_key, bucket: 'z0-bucket' })
      expect(resp).to be_finished
      expect(resp.reason_phrase).to eq('OK')
      expect(resp.status).to eq(200)
      expect(resp.req_id).not_to be_empty
      expect(resp.xlog).not_to be_empty
      expect(resp.duration).to be > 0
      expect(resp).not_to be_server_error
      expect(resp.error).to be_nil
    end
  end

  describe QiniuNg::HTTP::Middleware::RaiseError do
    before :all do
      WebMock.enable!
    end

    after :all do
      WebMock.disable!
    end

    after :each do
      WebMock.reset!
    end

    it 'should raise error for qiniu status code' do
      WebMock::API.stub_request(:get, "http://api.qiniu.com/v2/query?ak=#{access_key}&bucket=unexisted").to_return(status: 631, body: '{}')
      expect do
        domains_manager = QiniuNg::HTTP::DomainsManager.new
        QiniuNg.new_client(access_key: access_key, secret_key: secret_key, domains_manager: domains_manager)
               .bucket('unexisted').zone
      end.to raise_error(QiniuNg::HTTP::BucketNotFound)
    end

    it 'should raise error for qiniu status code' do
      WebMock::API.stub_request(:get, "http://api.qiniu.com/v2/query?ak=#{access_key}&bucket=unexisted").to_return(status: 579, body: '{}')
      expect do
        domains_manager = QiniuNg::HTTP::DomainsManager.new
        QiniuNg.new_client(access_key: access_key, secret_key: secret_key, domains_manager: domains_manager)
               .bucket('unexisted').zone
      end.to raise_error(QiniuNg::HTTP::CallbackFailed)
    end
  end

  describe QiniuNg::HTTP::DomainsManager do
    it 'should freeze a domain for 5 seconds' do
      manager = QiniuNg::HTTP::DomainsManager.new
      threads = []
      expect(manager.frozen?('up.qiniup.com')).to be false

      threads << Thread.new do
        manager.freeze('up.qiniup.com', frozen_seconds: 5)
        expect(manager.frozen?('up.qiniup.com')).to be true
        sleep(1)
        manager.freeze('upload.qiniup.com', frozen_seconds: 5)
        expect(manager.frozen?('upload.qiniup.com')).to be true
      end
      50.times do
        threads << Thread.new do
          expect(manager.frozen?('upload.qiniup.com')).to be false
          sleep(1)
          expect(manager.frozen?('http://up.qiniup.com')).to be true
          sleep(1)
          expect(manager.frozen?('https://up.qiniup.com')).to be true
          expect(manager.frozen?('https://upload.qiniup.com/abc')).to be true
          sleep(1)
          expect(manager.frozen?('up.qiniup.com/')).to be true
          expect(manager.frozen?('http://upload.qiniup.com')).to be true
          sleep(2)
          expect(manager.frozen?('up.qiniup.com/def/fgh.xyz')).to be false
          expect(manager.frozen?('https://up.qiniup.com/')).to be false
          sleep(1)
          expect(manager.frozen?('https://up.qiniup.com/')).to be false
          sleep(1)
          expect(manager.frozen?('https://upload.qiniup.com/def/fgh.xyz')).to be false
        end
      end
      threads.each(&:join)
    end
  end
end
