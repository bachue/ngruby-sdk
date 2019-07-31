# frozen_string_literal: true

require 'active_support/core_ext/securerandom'

RSpec.describe ActiveStorage::Service::QiniuNgService do
  service = nil
  before :all do
    configuration = {
      qiniu_ng: {
        service: 'QiniuNg',
        access_key: access_key,
        secret_key: secret_key,
        bucket: 'z0-bucket'
      }
    }.freeze
    service = ActiveStorage::Service.configure(:qiniu_ng, configuration)
  end

  it 'does upload test' do
    key = SecureRandom.base58(24)
    create_temp_file(kilo_size: 64 * (1 << 10)) do |file|
      file.rewind
      etag_expected = ::QiniuNg::Etag.from_file_path(file.path)
      service.upload key, file
      begin
        data = service.download(key)
        expect(data.bytesize).to eq(64 * (1 << 20))
        expect(::QiniuNg::Etag.from_data(data)).to eq etag_expected

        create_temp_file(kilo_size: 0) do |f|
          service.download(key) do |chunk|
            chunk_written = 0
            chunk_written += f.write(chunk[chunk_written..-1]) while chunk_written < chunk.bytesize
          end
          f.flush
          expect(File.size(f.path)).to eq(64 * (1 << 20))
          expect(::QiniuNg::Etag.from_file_path(f.path)).to eq etag_expected
        end
      ensure
        service.delete(key)
      end
    end
  end
end
