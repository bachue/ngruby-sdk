# frozen_string_literal: true

RSpec.describe QiniuNg::HTTP do
  describe QiniuNg::HTTP::Client do
    it 'should create qiniu_ng http response for faraday response' do
      resp = QiniuNg::HTTP.client.get('https://uc.qbox.me/v1/query', params: { ak: access_key, bucket: 'z0-bucket' })
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
    it 'should raise error for qiniu status code' do
      expect do
        QiniuNg::Client.new(access_key: access_key, secret_key: secret_key).bucket('unexisted-bucket').set_image('http://www.qiniu.com')
      end.to raise_error(QiniuNg::HTTP::BucketNotFound)
    end
  end
end
