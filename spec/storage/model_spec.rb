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
      expect(h[:scope]).to eq 'test'
    end

    it 'should be able to create upload token with bucket and key' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test', key: 'filename'
      expect(policy.bucket).to eq 'test'
      expect(policy.key).to eq 'filename'
      expect(policy.save_key).to be_nil
      expect(policy).not_to be_prefixal_scope
      expect(policy).not_to be_force_save_key
      h = policy.to_h
      expect(h[:scope]).to eq 'test:filename'
      expect(h[:saveKey]).to be_nil
      expect(h[:forceSaveKey]).to be_nil
    end

    it 'should be able to create upload token with bucket and key prefix' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new bucket: 'test', key_prefix: 'filename'
      expect(policy.bucket).to eq 'test'
      expect(policy.key).to eq 'filename'
      expect(policy.save_key).to be_nil
      expect(policy).to be_prefixal_scope
      expect(policy).not_to be_force_save_key
      h = policy.to_h
      expect(h[:scope]).to eq 'test:filename'
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

    it 'could set callback' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test')
                                                    .set_callback(%w[http://www.qiniu1.com http://www.qiniu2.com])
      expect(policy.callback_urls).to contain_exactly('http://www.qiniu1.com', 'http://www.qiniu2.com')
      h = policy.to_h
      expect(h[:callbackUrl]).to eq('http://www.qiniu1.com;http://www.qiniu2.com')
    end

    it 'should be able to convert it to json and convert it back' do
      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test', key: 'filename')
      policy.set_token_lifetime(seconds: 30)
            .detect_mime!.infrequent_storage!
            .limit_content_type('video/*')
            .set_callback(%w[http://www.qiniu1.com http://www.qiniu2.com])
      new_policy = QiniuNg::Storage::Model::UploadPolicy.from_json(policy.to_json)
      expect(new_policy.scope).to eq 'test:filename'
      expect(new_policy.bucket).to eq 'test'
      expect(new_policy.key).to eq 'filename'
      expect(new_policy).not_to be_prefixal_scope
      expect(new_policy.save_key).to be_nil
      expect(new_policy).not_to be_force_save_key
      expect(new_policy).not_to be_insert_only
      expect(new_policy).to be_detect_mime
      expect(new_policy).to be_infrequent_storage
      expect(new_policy.token_deadline).to be_within(5).of(Time.now + 30)
      expect(new_policy.end_user).to be_nil
      expect(new_policy.content_type_limit).to eq ['video/*']
      expect(new_policy.callback_urls).to contain_exactly('http://www.qiniu1.com', 'http://www.qiniu2.com')
      expect(new_policy.file_lifetime).to be_nil

      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test')
      new_policy = QiniuNg::Storage::Model::UploadPolicy.from_json(policy.to_json)
      expect(new_policy.scope).to eq 'test'
      expect(new_policy.bucket).to eq 'test'
      expect(new_policy.key).to be_nil
      expect(new_policy).not_to be_prefixal_scope
      expect(new_policy.save_key).to be_nil
      expect(new_policy).not_to be_force_save_key

      policy = QiniuNg::Storage::Model::UploadPolicy.new(bucket: 'test', key_prefix: 'file-')
      new_policy = QiniuNg::Storage::Model::UploadPolicy.from_json(policy.to_json)
      expect(new_policy.scope).to eq 'test:file-'
      expect(new_policy.bucket).to eq 'test'
      expect(new_policy.key).to eq 'file-'
      expect(new_policy).to be_prefixal_scope
      expect(new_policy.save_key).to be_nil
      expect(new_policy).not_to be_force_save_key
    end
  end
end
