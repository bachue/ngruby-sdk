# frozen_string_literal: true

RSpec.describe QiniuNg::Config do
  before :all do
    WebMock.enable!
  end

  after :all do
    WebMock.disable!
  end

  after :each do
    WebMock.reset!
  end

  it 'should get valid faraday connection' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"c": 3}')
    resp = QiniuNg::HTTP.client.get('http://www.qiniu.com', params: { a: 1, b: 2 })
    expect(resp.body).to eq 'c' => 3
  end

  it 'could set default options' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_options = QiniuNg::Config.default_faraday_options
      QiniuNg::Config.default_faraday_options = {
        params: { c: 3 }
      }
      resp = QiniuNg::HTTP.client.get('http://www.qiniu.com', params: { a: 1, b: 2 })
      expect(resp.body).to eq 'd' => 4
    ensure
      QiniuNg::Config.default_faraday_options = original_default_faraday_options
    end
  end

  it 'could set default config' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_config = QiniuNg::Config.default_faraday_config
      QiniuNg::Config.default_faraday_config = ->(conn) { conn.adapter :em_http }
      expect { QiniuNg::HTTP.client.get('http://www.qiniu.com', params: { a: 1, b: 2 }) }.to(
        raise_error(/missing dependency for Faraday::Adapter::EMHttp/)
      )
    ensure
      QiniuNg::Config.default_faraday_config = original_default_faraday_config
    end
  end
end
