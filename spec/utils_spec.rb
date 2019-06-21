# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Ngqiniu::Utils do
  describe Ngqiniu::Utils::Auth do
    dummy_access_key = 'abcdefghklmnopq'
    dummy_secret_key = '1234567890'
    dummy_auth = Ngqiniu::Utils::Auth.new(access_key: dummy_access_key, secret_key: dummy_secret_key)

    it 'should sign correctly' do
      expect(dummy_auth.sign('test')).to eq 'abcdefghklmnopq:mSNBTR7uS2crJsyFr2Amwv1LaYg='
    end

    it 'should sign with data correctly' do
      expect(dummy_auth.sign_with_data('test')).to eq 'abcdefghklmnopq:-jP8eEV9v48MkYiBGs81aDxl60E=:dGVzdA=='
    end

    it 'should sign request correctly' do
      expect(dummy_auth.sign_request('http://www.qiniu.com?go=1', body: 'test', content_type: '')).to(
        eq 'abcdefghklmnopq:cFyRVoWrE3IugPIMP5YJFTO-O-Y='
      )
      expect(dummy_auth.sign_request('http://www.qiniu.com?go=1', body: 'test', content_type: 'application/x-www-form-urlencoded')).to(
        eq 'abcdefghklmnopq:svWRNcacOE-YMsc70nuIYdaa1e4='
      )
    end

    it 'should sign download url correctly' do
      expect(dummy_auth.sign_download_url_with_deadline(
               'http://www.qiniu.com?go=1', deadline: Time.at(1_234_567_890 + 3600)
             )).to eq 'http://www.qiniu.com?go=1&e=1234571490&token=abcdefghklmnopq:8vzBeLZ9W3E4kbBLFLW0Xe0u7v4='
    end
  end
end
