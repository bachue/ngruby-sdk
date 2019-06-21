# frozen_string_literal: true

RSpec.describe QiniuNg::HTTP do
  it 'should create qiniu_ng http response for faraday response' do
    good_resp = QiniuNg::HTTP.client.get('https://uc.qbox.me/v1/query', params: { ak: access_key, bucket: 'z0-bucket' })
    expect(good_resp).to be_finished
    expect(good_resp.reason_phrase).to eq('OK')
    expect(good_resp.status).to eq(200)
    expect(good_resp.req_id).not_to be_empty
    expect(good_resp.xlog).not_to be_empty
    expect(good_resp.duration).to be > 0
    expect(good_resp).not_to be_server_error
    expect(good_resp.error).to be_nil
  end

  it 'should get error message from http response' do
    bad_resp = QiniuNg::HTTP.client.get('https://uc.qbox.me/v1/query', params: { ak: access_key, bucket: 'unexisted-bucket' })
    expect(bad_resp).to be_finished
    expect(bad_resp.reason_phrase).to eq('status code 631')
    expect(bad_resp.status).to eq(631)
    expect(bad_resp.req_id).not_to be_empty
    expect(bad_resp.xlog).not_to be_empty
    expect(bad_resp.duration).to be > 0
    expect(bad_resp).not_to be_server_error
    expect(bad_resp.error).to eq('no such bucket')
  end
end
