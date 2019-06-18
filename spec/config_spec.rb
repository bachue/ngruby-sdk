require 'ngruby'

RSpec.describe Ngruby::Config do
  it 'should get valid faraday connection' do
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2').to_return(headers: {'Content-Type': 'application/json'}, body: '{"c": 3}')
    conn = Ngruby::Config.default_faraday_connection.call
    resp = conn.get("http://www.qiniu.com", { a: 1, b: 2 })
    expect(resp.body).to eq({'c' => 3})
  end

  it 'could set default options' do
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3').to_return(headers: {'Content-Type': 'application/json'}, body: '{"d": 4}')
    begin
      original_default_faraday_options = Ngruby::Config.default_faraday_options
      Ngruby::Config.default_faraday_options = {
        params: { c: 3 }
      }
      conn = Ngruby::Config.default_faraday_connection.call
      resp = conn.get("http://www.qiniu.com", { a: 1, b: 2 })
      expect(resp.body).to eq({'d' => 4})
    ensure
      Ngruby::Config.default_faraday_options = original_default_faraday_options
    end
  end

  it 'could set default config' do
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3').to_return(headers: {'Content-Type': 'application/json'}, body: '{"d": 4}')
    begin
      original_default_faraday_config = Ngruby::Config.default_faraday_config
      Ngruby::Config.default_faraday_config = ->(conn) { conn.adapter :em_http }
      conn = Ngruby::Config.default_faraday_connection.call
      expect { conn.get("http://www.qiniu.com", { a: 1, b: 2 }) }.to raise_error(/missing dependency for Faraday::Adapter::EMHttp/)
    ensure
      Ngruby::Config.default_faraday_config = original_default_faraday_config
    end
  end
end