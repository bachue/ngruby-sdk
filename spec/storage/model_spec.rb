# frozen_string_literal: true

RSpec.describe QiniuNg::Storage::Model do
  describe QiniuNg::Storage::Model::Entry do
    it 'should be able to parse entry from string' do
      entry = QiniuNg::Storage::Model::Entry.parse('test:filename')
      expect(entry.bucket).to eq('test')
      expect(entry.key).to eq('filename')
    end

    it 'should be able to decode entry from string' do
      entry = QiniuNg::Storage::Model::Entry.decode(Base64.urlsafe_encode64('test:filename'))
      expect(entry.bucket).to eq('test')
      expect(entry.key).to eq('filename')
    end
  end

  describe QiniuNg::Storage::Model::UploadPolicy do
    it 'should be able to create upload token with only bucket' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test'
      expect(policy.bucket).to eq 'test'
      h = policy.to_h
      expect(h[:scope]).to eq Base64.urlsafe_encode64('test')
    end

    it 'should be able to create upload token with bucket and key' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test', key: 'filename'
      expect(policy.bucket).to eq 'test'
      expect(policy.key).to eq 'filename'
      expect(policy.save_key).to eq 'filename'
      expect(policy).not_to be_prefixal_scope
      expect(policy).to be_force_save_key
      h = policy.to_h
      expect(h[:scope]).to eq Base64.urlsafe_encode64('test:filename')
      expect(h[:saveKey]).to eq 'filename'
      expect(h[:forceSaveKey]).to be true
    end

    it 'should be able to create upload token with bucket and key prefix' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test', key_prefix: 'filename'
      expect(policy.bucket).to eq 'test'
      expect(policy.key).to eq 'filename'
      expect(policy.save_key).to be_nil
      expect(policy).to be_prefixal_scope
      expect(policy).not_to be_force_save_key
      h = policy.to_h
      expect(h[:scope]).to eq Base64.urlsafe_encode64('test:filename')
      expect(h[:isPrefixalScope]).to eq 1
    end

    it 'could set lifetime of the uptoken' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test').set_token_lifetime(seconds: 30)
      expect(policy.token_deadline).to be_within(1).of(Time.now + 30)
      h = policy.to_h
      expect(h[:deadline]).to be_within(1).of(Time.now.to_i + 30)
      sleep(1)
      expect(policy.token_lifetime.to_i).to be <= 29
    end

    it 'could set to infrequent storage' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test'
      expect(policy).not_to be_infrequent_storage
      expect(policy).to be_normal_storage
      expect(policy).not_to be_detect_mime
      policy.infrequent_storage!.detect_mime!
      expect(policy).to be_infrequent_storage
      expect(policy).not_to be_normal_storage
      expect(policy).to be_detect_mime
      policy.normal_storage!
      expect(policy).not_to be_infrequent_storage
      expect(policy).to be_normal_storage
      expect(policy).to be_detect_mime
    end

    it 'could set content type limit' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test').limit_content_type('video/*')
      expect(policy.content_type_limit).to contain_exactly('video/*')
      policy.limit_content_type(['video/*', 'image/*'])
      expect(policy.content_type_limit).to contain_exactly('video/*', 'image/*')
      h = policy.to_h
      expect(h[:mimeLimit]).to eq('video/*;image/*')
    end
  end
end
