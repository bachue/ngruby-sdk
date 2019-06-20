# frozen_string_literal: true

RSpec.describe Ngqiniu::Config do
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
    conn = Ngqiniu::Config.default_faraday_connection.call
    resp = conn.get('http://www.qiniu.com', a: 1, b: 2)
    expect(resp.body).to eq 'c' => 3
  end

  it 'could set default options' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_options = Ngqiniu::Config.default_faraday_options
      Ngqiniu::Config.default_faraday_options = {
        params: { c: 3 }
      }
      conn = Ngqiniu::Config.default_faraday_connection.call
      resp = conn.get('http://www.qiniu.com', a: 1, b: 2)
      expect(resp.body).to eq 'd' => 4
    ensure
      Ngqiniu::Config.default_faraday_options = original_default_faraday_options
    end
  end

  it 'could set default config' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_config = Ngqiniu::Config.default_faraday_config
      Ngqiniu::Config.default_faraday_config = ->(conn) { conn.adapter :em_http }
      conn = Ngqiniu::Config.default_faraday_connection.call
      expect { conn.get('http://www.qiniu.com', a: 1, b: 2) }.to(
        raise_error(/missing dependency for Faraday::Adapter::EMHttp/)
      )
    ensure
      Ngqiniu::Config.default_faraday_config = original_default_faraday_config
    end
  end

  it 'could set default connection' do
    WebMock::API.stub_request(:get, 'http://www.qiniu.com/?a=1&b=2')
                .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"c": 3}')
    begin
      original_default_faraday_connection = Ngqiniu::Config.default_faraday_connection
      Ngqiniu::Config.default_faraday_connection = lambda do
        Faraday.new do |conn|
          conn.adapter Faraday.default_adapter
        end
      end
      conn = Ngqiniu::Config.default_faraday_connection.call
      resp = conn.get('http://www.qiniu.com', a: 1, b: 2)
      expect(resp.body).to eq '{"c": 3}'
    ensure
      Ngqiniu::Config.default_faraday_connection = original_default_faraday_connection
    end
  end
end
