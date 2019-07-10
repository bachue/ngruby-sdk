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
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2')
      .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"c": 3}')
    resp = QiniuNg::HTTP.client.get('/', 'http://www.qiniu.com', params: { a: 1, b: 2 })
    expect(resp.body).to eq 'c' => 3
  end

  it 'could set default options' do
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
      .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_options = QiniuNg::Config.default_faraday_options
      QiniuNg.config params: { c: 3 }
      resp = QiniuNg::HTTP.client.get('/', 'http://www.qiniu.com', params: { a: 1, b: 2 })
      expect(resp.body).to eq 'd' => 4
    ensure
      QiniuNg::Config.default_faraday_options = original_default_faraday_options
    end
  end

  it 'could set default config' do
    stub_request(:get, 'http://www.qiniu.com/?a=1&b=2&c=3')
      .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"d": 4}')
    begin
      original_default_faraday_config = QiniuNg::Config.default_faraday_config
      QiniuNg.config { |conn| conn.adapter :em_http }
      expect do
        QiniuNg::HTTP.client.get('/', 'http://www.qiniu.com', params: { a: 1, b: 2 })
      end.to raise_error(/missing dependency for Faraday::Adapter::EMHttp/)
    ensure
      QiniuNg::Config.default_faraday_config = original_default_faraday_config
    end
  end

  it 'could set default scheme' do
    stub_request(:get, 'https://api.qiniu.com/v2/query?ak=ak&bucket=bk')
      .to_return(headers: { 'Content-Type': 'application/json' }, body: '{"ttl":86400,"io":{"src":{"main":["iovip.q' \
                                                                        'box.me"]}},"up":{"acc":{"main":["upload.qin' \
                                                                        'iup.com"],"backup":["upload-jjh.qiniup.com"' \
                                                                        ',"upload-xs.qiniup.com"]},"old_acc":{"main"' \
                                                                        ':["upload.qbox.me"],"info":"compatible to n' \
                                                                        'on-SNI device"},"old_src":{"main":["up.qbox' \
                                                                        '.me"],"info":"compatible to non-SNI device"' \
                                                                        '},"src":{"main":["up.qiniup.com"],"backup":' \
                                                                        '["up-jjh.qiniup.com","up-xs.qiniup.com"]}}}')
    begin
      original_default_use_https = QiniuNg::Config.use_https
      QiniuNg.config use_https: true
      QiniuNg::Zone.auto.query(access_key: 'ak', bucket: 'bk')
    ensure
      QiniuNg::Config.use_https = original_default_use_https
    end
  end
end
