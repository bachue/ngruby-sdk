# frozen_string_literal: true

RSpec.describe QiniuNg::Processing do
  client = nil
  bucket = nil

  before :all do
    client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
    bucket = client.bucket('z0-bucket')
  end

  it 'should process file by pfop' do
    bucket.entry('test-video.mp4')
  end
end
