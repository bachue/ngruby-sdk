# frozen_string_literal: true

RSpec.describe CarrierWave::Storage::QiniuNg do
  before :all do
    CarrierWave.configure do |config|
      config.storage = :qiniu_ng
      config.qiniu_access_key = access_key
      config.qiniu_secret_key = secret_key
      config.qiniu_bucket_name = 'z0-bucket'
    end
  end

  before :each do
    CarrierWaveTestForQiniuNg.setup_db
  end

  after :each do
    CarrierWaveTestForQiniuNg.drop_db
  end

  it 'does upload test' do
    create_temp_file(kilo_size: 64 * (1 << 10)) do |file|
      etag_expected = ::QiniuNg::Etag.from_file_path(file.path)
      tar = CarrierWaveTestForQiniuNg::TestActiveRecord.new(test: file)
      tar.save!
      create_temp_file(kilo_size: 0) do |f|
        tar.test.url.download_to(f.path)
        expect(File.size(f.path)).to eq(64 * (1 << 20))
        expect(::QiniuNg::Etag.from_file_path(f.path)).to eq etag_expected
      end
    end
  end
end
