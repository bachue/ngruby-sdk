# frozen_string_literal: true

RSpec.describe QiniuNg::Client do
  it 'should get all bucket names' do
    client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
    expect(client.bucket_names).to include('z0-bucket', 'z1-bucket', 'na-bucket')
  end
end
