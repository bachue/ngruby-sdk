# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe QiniuNg::Utils do
  describe QiniuNg::Auth do
    describe '#sign' do
      dummy_access_key = 'abcdefghklmnopq'
      dummy_secret_key = '1234567890'
      dummy_auth = QiniuNg::Auth.new(access_key: dummy_access_key, secret_key: dummy_secret_key)

      it 'should sign correctly' do
        expect(dummy_auth.sign('hello')).to eq 'abcdefghklmnopq:b84KVc-LroDiz0ebUANfdzSRxa0='
        expect(dummy_auth.sign('world')).to eq 'abcdefghklmnopq:VjgXt0P_nCxHuaTfiFz-UjDJ1AQ='
        expect(dummy_auth.sign('-test')).to eq 'abcdefghklmnopq:vYKRLUoXRlNHfpMEQeewG0zylaw='
        expect(dummy_auth.sign('ba#a-')).to eq 'abcdefghklmnopq:2d_Yr6H1GdTKg3RvMtpHOhi047M='
      end

      it 'should sign with data correctly' do
        expect(dummy_auth.sign_with_data('hello')).to eq 'abcdefghklmnopq:BZYt5uVRy1RVt5ZTXbaIt2ROVMA=:aGVsbG8='
        expect(dummy_auth.sign_with_data('world')).to eq 'abcdefghklmnopq:Wpe04qzPphiSZb1u6I0nFn6KpZg=:d29ybGQ='
        expect(dummy_auth.sign_with_data('-test')).to eq 'abcdefghklmnopq:HlxenSSP_6BbaYNzx1fyeyw8v1Y=:LXRlc3Q='
        expect(dummy_auth.sign_with_data('ba#a-')).to eq 'abcdefghklmnopq:kwzeJrFziPDMO4jv3DKVLDyqud0=:YmEjYS0='
      end

      it 'should sign request correctly' do
        expect(dummy_auth.sign_request('', content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('', content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('', method: 'GET', content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('', method: 'POST', content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("\n")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("\nname=test&language=go")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com?v=2', content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("?v=2\nname=test&language=go")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com/find/sdk?v=2', content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("/find/sdk?v=2\nname=test&language=go")
        )
      end

      it 'should sign request v2 correctly' do
        expect(dummy_auth.sign_request('', version: 2, content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("GET \nHost: \nContent-Type: application/json\n\n{\"name\": \"test\"}")
        )
        expect(dummy_auth.sign_request('', version: 2, content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("GET \nHost: \n\n")
        )
        expect(dummy_auth.sign_request('', method: 'GET', version: 2, content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("GET \nHost: \n\n")
        )
        expect(dummy_auth.sign_request('', method: 'POST', version: 2, content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("POST \nHost: \nContent-Type: application/json\n\n{\"name\": \"test\"}")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', version: 2, content_type: nil, body: '{"name": "test"}')).to(
          eq dummy_auth.sign("GET \nHost: upload.qiniup.com\n\n")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', version: 2, content_type: 'application/json', body: '{"name": "test"}')).to(
          eq dummy_auth.sign("GET \nHost: upload.qiniup.com\nContent-Type: application/json\n\n{\"name\": \"test\"}")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com', version: 2, content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("GET \nHost: upload.qiniup.com\nContent-Type: application/x-www-form-urlencoded\n\nname=test&language=go")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com?v=2', version: 2, content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("GET ?v=2\nHost: upload.qiniup.com\nContent-Type: application/x-www-form-urlencoded\n\nname=test&language=go")
        )
        expect(dummy_auth.sign_request('http://upload.qiniup.com/find/sdk?v=2', version: 2, content_type: 'application/x-www-form-urlencoded', body: 'name=test&language=go')).to(
          eq dummy_auth.sign("GET /find/sdk?v=2\nHost: upload.qiniup.com\nContent-Type: application/x-www-form-urlencoded\n\nname=test&language=go")
        )
      end
    end

    describe '#sign_download_url_with_deadline' do
      it 'should sign download url correctly' do
        dummy_auth = QiniuNg::Auth.new(access_key: 'abcdefghklmnopq', secret_key: '1234567890')
        expect(dummy_auth.sign_download_url_with_deadline('http://www.qiniu.com?go=1', deadline: Time.at(1_234_567_890 + 3600))).to(
          eq 'http://www.qiniu.com?go=1&e=1234571490&token=abcdefghklmnopq:8vzBeLZ9W3E4kbBLFLW0Xe0u7v4='
        )
      end

      %w[4k 1m 4m 8m 16m 64m 1g].each do |size|
        it "should download #{size} file correctly" do
          real_auth = QiniuNg::Auth.new(access_key: access_key, secret_key: secret_key)
          url = real_auth.sign_download_url_with_lifetime("http://z1-bucket.kodo-test.qiniu-solutions.com/#{size}", lifetime: { seconds: 30 })
          expect(Faraday.head(url)).to be_success
        end
      end
    end
  end

  describe QiniuNg::Utils::Etag do
    describe '#from_data' do
      it 'should calculate etag from string' do
        expect(QiniuNg::Etag.from_data('')).to eq('Fto5o-5ea0sNMlW_75VgGJCv2AcJ')
        expect(QiniuNg::Etag.from_data('etag')).to eq('FpLiADEaVoALPkdb8tJEJyRTXoe_')
      end
    end

    describe '#from_file_path' do
      it 'should calculate etag from file path' do
        expect(QiniuNg::Etag.from_file_path(create_temp_file(kilo_size: 1024))).to(
          eq 'Foyl8onxBLWeRLL5oItRJphv6i4b'
        )
        expect(QiniuNg::Etag.from_file_path(create_temp_file(kilo_size: 4 * 1024))).to(
          eq 'FicHOveBNs5Kn9d74M3b9tI4D-8r'
        )
        expect(QiniuNg::Etag.from_file_path(create_temp_file(kilo_size: 5 * 1024))).to(
          eq 'lg-Eb5KFCuZn-cUfj_oS2PPOU9xy'
        )
        expect(QiniuNg::Etag.from_file_path(create_temp_file(kilo_size: 8 * 1024))).to(
          eq 'lkSKZOMToDp-EqLDVuT1pyjQssl-'
        )
        expect(QiniuNg::Etag.from_file_path(create_temp_file(kilo_size: 9 * 1024))).to(
          eq 'ljgVjMtyMsOgIySv79U8Qz4TrUO4'
        )
      end
    end
  end

  describe QiniuNg::Utils::Bool do
    it 'should convert value to bool' do
      expect(QiniuNg::Bool.to_bool(1)).to be true
      expect(QiniuNg::Bool.to_bool(0)).to be false
      expect(QiniuNg::Bool.to_bool(true)).to be true
      expect(QiniuNg::Bool.to_bool(false)).to be false
      expect(QiniuNg::Bool.to_bool(nil)).to be false
    end

    it 'should convert value to int' do
      expect(QiniuNg::Bool.to_int(1)).to eq 1
      expect(QiniuNg::Bool.to_int(0)).to eq 0
      expect(QiniuNg::Bool.to_int(true)).to eq 1
      expect(QiniuNg::Bool.to_int(false)).to eq 0
      expect(QiniuNg::Bool.to_int(nil)).to eq 0
    end
  end
end
