# frozen_string_literal: true

RSpec.describe Ngqiniu::Common do
  it 'should returns predefined zone' do
    zone0 = Ngqiniu::Zone.huadong
    expect(zone0.region).to eq('z0')
    expect(zone0.up_http).to eq('http://up.qiniu.com')
    expect(zone0.up_https).to eq('https://up.qbox.me')
    expect(zone0.up_backup_http).to eq('http://upload.qiniu.com')
    expect(zone0.up_backup_https).to eq('https://upload.qbox.me')
    expect(zone0.io_vip_http).to eq('http://iovip.qbox.me')
    expect(zone0.io_vip_https).to eq('https://iovip.qbox.me')
    expect(zone0.rs_http).to eq('http://rs.qiniu.com')
    expect(zone0.rs_https).to eq('https://rs.qbox.me')
    expect(zone0.rsf_http).to eq('http://rsf.qiniu.com')
    expect(zone0.rsf_https).to eq('https://rsf.qbox.me')
    expect(zone0.api_http).to eq('http://api.qiniu.com')
    expect(zone0.api_https).to eq('https://api.qiniu.com')

    zone1 = Ngqiniu::Zone.zone1
    expect(zone1.region).to eq('z1')
    expect(zone1.up_http).to eq('http://up-z1.qiniu.com')
    expect(zone1.up_https).to eq('https://up-z1.qbox.me')
    expect(zone1.up_backup_http).to eq('http://upload-z1.qiniu.com')
    expect(zone1.up_backup_https).to eq('https://upload-z1.qbox.me')
    expect(zone1.io_vip_http).to eq('http://iovip-z1.qbox.me')
    expect(zone1.io_vip_https).to eq('https://iovip-z1.qbox.me')
    expect(zone1.rs_http).to eq('http://rs-z1.qiniu.com')
    expect(zone1.rs_https).to eq('https://rs-z1.qbox.me')
    expect(zone1.rsf_http).to eq('http://rsf-z1.qiniu.com')
    expect(zone1.rsf_https).to eq('https://rsf-z1.qbox.me')
    expect(zone1.api_http).to eq('http://api-z1.qiniu.com')
    expect(zone1.api_https).to eq('https://api-z1.qiniu.com')
  end

  it 'could use access key & bucket to judge which zone is better for me' do
    auto_zone = Ngqiniu::Zone.auto.query(access_key: access_key, bucket: 'na-bucket')
    expect(auto_zone.region).to eq('auto')
    expect(auto_zone.up_http).to eq('http://up-na0.qiniu.com')
    expect(auto_zone.up_https).to eq('https://up-na0.qbox.me')
    expect(auto_zone.up_backup_http).to eq('http://upload-na0.qiniu.com')
    expect(auto_zone.up_backup_https).to eq('https://upload-na0.qbox.me')
    expect(auto_zone.io_vip_http).to eq('http://iovip-na0.qbox.me')
    expect(auto_zone.io_vip_https).to eq('https://iovip-na0.qbox.me')
    expect(auto_zone.rs_http).to eq('http://rs-na0.qiniu.com')
    expect(auto_zone.rs_https).to eq('https://rs-na0.qbox.me')
    expect(auto_zone.rsf_http).to eq('http://rsf-na0.qiniu.com')
    expect(auto_zone.rsf_https).to eq('https://rsf-na0.qbox.me')
    expect(auto_zone.api_http).to eq('http://api-na0.qiniu.com')
    expect(auto_zone.api_https).to eq('https://api-na0.qiniu.com')
  end
end
