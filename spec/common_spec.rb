# frozen_string_literal: true

RSpec.describe QiniuNg::Common do
  it 'should returns predefined zone' do
    region0 = QiniuNg::Region.huadong
    expect(region0.region_id).to eq('z0')
    expect(region0.up_http_urls).to eq(%w[http://upload.qiniup.com http://up.qiniup.com
                                          http://upload.qbox.me http://up.qbox.me])
    expect(region0.up_https_urls).to eq(%w[https://upload.qiniup.com https://up.qiniup.com
                                           https://upload.qbox.me https://up.qbox.me])
    expect(region0.io_http_urls).to eq(%w[http://iovip.qbox.me])
    expect(region0.io_https_urls).to eq(%w[https://iovip.qbox.me])
    expect(region0.rs_http_url).to eq('http://rs.qiniu.com')
    expect(region0.rs_https_url).to eq('https://rs.qbox.me')
    expect(region0.rsf_http_url).to eq('http://rsf.qiniu.com')
    expect(region0.rsf_https_url).to eq('https://rsf.qbox.me')
    expect(region0.api_http_url).to eq('http://api.qiniu.com')
    expect(region0.api_https_url).to eq('https://api.qiniu.com')

    region1 = QiniuNg::Region.zone1
    expect(region1.region_id).to eq('z1')
    expect(region1.up_http_urls).to eq(%w[http://upload-z1.qiniup.com http://up-z1.qiniup.com
                                          http://upload-z1.qbox.me http://up-z1.qbox.me])
    expect(region1.up_https_urls).to eq(%w[https://upload-z1.qiniup.com https://up-z1.qiniup.com
                                           https://upload-z1.qbox.me https://up-z1.qbox.me])
    expect(region1.io_http_urls).to eq(%w[http://iovip-z1.qbox.me])
    expect(region1.io_https_urls).to eq(%w[https://iovip-z1.qbox.me])
    expect(region1.rs_http_url).to eq('http://rs-z1.qiniu.com')
    expect(region1.rs_https_url).to eq('https://rs-z1.qbox.me')
    expect(region1.rsf_http_url).to eq('http://rsf-z1.qiniu.com')
    expect(region1.rsf_https_url).to eq('https://rsf-z1.qbox.me')
    expect(region1.api_http_url).to eq('http://api-z1.qiniu.com')
    expect(region1.api_https_url).to eq('https://api-z1.qiniu.com')
  end

  it 'could use access key & bucket to judge which zone is better for me' do
    auto_region = QiniuNg::Region.auto.query(access_key: access_key, bucket: 'na-bucket')
    expect(auto_region.region_id).to eq('na0')
    expect(auto_region.up_http_urls).to eq(%w[http://upload-na0.qiniup.com http://up-na0.qiniup.com http://upload-na0.qbox.me http://up-na0.qbox.me])
    expect(auto_region.up_https_urls).to eq(%w[https://upload-na0.qiniup.com https://up-na0.qiniup.com https://upload-na0.qbox.me https://up-na0.qbox.me])
    expect(auto_region.io_http_urls).to eq(%w[http://iovip-na0.qbox.me])
    expect(auto_region.io_https_urls).to eq(%w[https://iovip-na0.qbox.me])
    expect(auto_region.rs_http_url).to eq('http://rs-na0.qiniu.com')
    expect(auto_region.rs_https_url).to eq('https://rs-na0.qbox.me')
    expect(auto_region.rsf_http_url).to eq('http://rsf-na0.qiniu.com')
    expect(auto_region.rsf_https_url).to eq('https://rsf-na0.qbox.me')
    expect(auto_region.api_http_url).to eq('http://api-na0.qiniu.com')
    expect(auto_region.api_https_url).to eq('https://api-na0.qiniu.com')
  end
end
