# frozen_string_literal: true

RSpec.describe QiniuNg::Client do
  describe QiniuNg::Storage::BucketManager do
    it 'should get all bucket names' do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      expect(client.bucket_names).to include('z0-bucket', 'z1-bucket', 'na-bucket')
    end

    it 'should create / drop bucket' do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      bucket = client.create_bucket("test-bucket-#{time_id}")
      begin
        expect(client.bucket_names).to include(bucket.name)
      ensure
        client.drop_bucket(bucket.name)
      end
    end
  end

  describe QiniuNg::Storage::Bucket do
    client = nil
    bucket = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      bucket = client.create_bucket("test-bucket-#{time_id}")
    end

    after :all do
      bucket.drop
    end

    it 'should get bucket domains' do
      expect(client.bucket('z0-bucket').domains).to include('z0-bucket.kodo-test.qiniu-solutions.com')
    end

    it 'should set / unset image for bucket' do
      expect(bucket.image).to be_nil
      begin
        bucket.set_image 'http://www.qiniu.com', source_host: 'z0-bucket.kodo-test.qiniu-solutions.com'
        expect(bucket.image.source_url).to eq('http://www.qiniu.com')
        expect(bucket.image.source_host).to eq('z0-bucket.kodo-test.qiniu-solutions.com')
      ensure
        bucket.unset_image
      end
    end

    it 'should prefetch image from remote url' do
      expect(bucket.image).to be_nil
      begin
        bucket.set_image 'https://mars-assets.qnssl.com'
        expect(bucket.entry('qiniulog/img-slogan-white-en.png').prefetch.stat.mime_type).to eq 'image/png'
        expect(bucket.entry('qiniulog/img-slogan-blue-en.png').prefetch.stat.mime_type).to eq 'image/png'
        expect(bucket.entry('qiniulogo/img-horizontal-white-en.png').prefetch.stat.mime_type).to eq 'image/png'
        expect(bucket.entry('qiniulogo/img-verical-white-en.png').prefetch.stat.mime_type).to eq 'image/png'
      ensure
        bucket.unset_image
      end
    end

    it 'should add rules to life cycle rules' do
      rules = bucket.life_cycle_rules
      expect(rules.all).to be_empty
      rules.new(name: 'test_rule1').delete_after(days: 7).to_line_after(days: 3).create!
      rules.new(name: 'test_rule2').start_with('temp').delete_after(days: 3).always_to_line.create!
      expect(rules.all.size).to eq 2
      test_rule1 = rules.all.detect { |rule| rule.name == 'test_rule1' }
      expect(test_rule1.prefix).to be_empty
      expect(test_rule1.delete_after_days).to eq 7
      expect(test_rule1.to_line_after_days).to eq 3
      expect(test_rule1).not_to be_always_to_line
      test_rule2 = rules.all.detect { |rule| rule.name == 'test_rule2' }
      expect(test_rule2.prefix).to eq 'temp'
      expect(test_rule2.delete_after_days).to eq 3
      expect(test_rule2).to be_always_to_line
      rules.new(name: 'test_rule2').start_with('fake').delete_after(days: 3).always_to_line.replace!
      expect(rules.all.size).to eq 2
      test_rule1 = rules.all.detect { |rule| rule.name == 'test_rule1' }
      expect(test_rule1.prefix).to be_empty
      expect(test_rule1.delete_after_days).to eq 7
      expect(test_rule1.to_line_after_days).to eq 3
      expect(test_rule1).not_to be_always_to_line
      test_rule2 = rules.all.detect { |rule| rule.name == 'test_rule2' }
      expect(test_rule2.prefix).to eq 'fake'
      expect(test_rule2.delete_after_days).to eq 3
      expect(test_rule2).to be_always_to_line
      rules.delete(name: 'test_rule2')
      expect(rules.all.size).to eq 1
      test_rule1 = rules.all.detect { |rule| rule.name == 'test_rule1' }
      expect(test_rule1.prefix).to be_empty
      expect(test_rule1.delete_after_days).to eq 7
      expect(test_rule1.to_line_after_days).to eq 3
      expect(test_rule1).not_to be_always_to_line
      rules.delete(name: 'test_rule1')
      expect(rules.all).to be_empty
    end

    it 'should add rules to bucket event rules' do
      rules = bucket.bucket_event_rules
      expect(rules.all).to be_empty
      event_types1 = [QiniuNg::Storage::Model::BucketEventType::PUT, QiniuNg::Storage::Model::BucketEventType::MKFILE]
      rules.new(name: 'test_rule1').listen_on(event_types1).callback('http://www.test1.com').create!
      event_types2 = [QiniuNg::Storage::Model::BucketEventType::COPY, QiniuNg::Storage::Model::BucketEventType::MOVE]
      rules.new(name: 'test_rule2').listen_on(event_types2).callback('http://www.test2.com', host: 'www.test2.com').start_with('prefix-').end_with('.mp3').create!
      expect(rules.all.size).to eq 2
      test_rule1 = rules.all.detect { |rule| rule.name == 'test_rule1' }
      expect(test_rule1.prefix).to be_empty
      expect(test_rule1.suffix).to be_empty
      expect(test_rule1.events).to match_array(event_types1)
      expect(test_rule1.callback_urls).to eq ['http://www.test1.com']
      expect(test_rule1.callback_host).to be_empty
      test_rule2 = rules.all.detect { |rule| rule.name == 'test_rule2' }
      expect(test_rule2.prefix).to eq 'prefix-'
      expect(test_rule2.suffix).to eq '.mp3'
      expect(test_rule2.events).to match_array(event_types2)
      expect(test_rule2.callback_urls).to eq %w[http://www.test2.com]
      expect(test_rule2.callback_host).to eq 'www.test2.com'
      rules.delete(name: 'test_rule1')
      expect(rules.all.size).to eq 1
    end

    it 'should set / get cors rules' do
      cors_rules = bucket.cors_rules
      new_rule1 = cors_rules.new(%w[http://www.test1.com http://www.test2.com], %w[GET DELETE]).cache_max_age(days: 365)
      new_rule2 = cors_rules.new(%w[http://www.test3.com http://www.test4.com], %w[POST PUT]).cache_max_age(days: 365)
      cors_rules.set([new_rule1, new_rule2])
      rules = cors_rules.all
      expect(rules.size).to eq 2
      cors_rules.clear
      rules = cors_rules.all
      expect(rules).to be_empty
    end

    it 'should update bucket acl' do
      expect(bucket).not_to be_private
      begin
        bucket.private!
        expect(bucket).to be_private
      ensure
        bucket.public!
        expect(bucket).not_to be_private
      end
    end

    it 'should update bucket noIndexPage' do
      expect(bucket).to have_index_page
      begin
        bucket.disable_index_page
        expect(bucket).not_to have_index_page
      ensure
        bucket.enable_index_page
        expect(bucket).to have_index_page
      end
    end
  end

  describe QiniuNg::Storage::Entry do
    client = nil
    bucket = nil
    entry = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      bucket = client.bucket('z0-bucket')
    end

    describe 'Basic' do
      before :all do
        entry = bucket.entry("16k-#{Time.now.usec}")
        bucket.uploader.upload(filepath: create_temp_file(kilo_size: 16), upload_token: entry.upload_token)
      end

      after :all do
        entry.try_delete
      end

      it 'should disable / enable the entry' do
        public_url = entry.download_url
        private_url = public_url.private
        expect(head(public_url.refresh)).to be_success
        expect(head(private_url.refresh)).to be_success
        begin
          entry.disable!
          expect { head(public_url.refresh).status }.to eventually eq 403
          expect { head(private_url.refresh).status }.to eventually eq 403
        ensure
          entry.enable!
          expect { head(public_url.refresh) }.to eventually be_success
          expect { head(private_url.refresh) }.to eventually be_success
        end
      end

      it 'should set entry to infrequent / normal storage' do
        expect(entry.stat).to be_normal_storage
        expect(entry.stat).not_to be_infrequent_storage
        begin
          entry.infrequent_storage!
          expect { entry.stat }.to eventually_not be_normal_storage
          expect { entry.stat }.to eventually be_infrequent_storage
        ensure
          entry.normal_storage!
          expect { entry.stat }.to eventually be_normal_storage
          expect { entry.stat }.to eventually_not be_infrequent_storage
        end
      end

      it 'should change mime_type' do
        original_mime_type = entry.stat.mime_type
        expect(entry.stat.mime_type).not_to eq 'application/json'
        begin
          entry.change_mime_type 'application/json'
          expect { entry.stat.mime_type }.to eventually eq 'application/json'
        ensure
          entry.change_mime_type original_mime_type
          expect { entry.stat.mime_type }.to eventually_not eq 'application/json'
        end
      end

      it 'should rename the entry' do
        old_public_url = entry.download_url
        expect(head(old_public_url.refresh)).to be_success
        new_entry = bucket.entry("16K-#{Time.now.usec}")
        new_public_url = new_entry.download_url
        begin
          entry.rename_to(new_entry.key)
          expect { head(old_public_url.refresh).status }.to eventually eq 404
          expect { head(new_public_url.refresh) }.to eventually be_success
        ensure
          new_entry.rename_to(entry.key)
          expect { head(old_public_url.refresh) }.to eventually be_success
          expect { head(new_public_url.refresh).status }.to eventually eq 404
        end
      end

      it 'should copy / delete the entry' do
        old_public_url = entry.download_url
        expect(head(old_public_url.refresh)).to be_success
        new_entry = bucket.entry("16K-#{Time.now.usec}")
        new_public_url = new_entry.download_url
        begin
          entry.copy_to(bucket.name, new_entry.key)
          expect { head(old_public_url.refresh) }.to eventually be_success
          expect { head(new_public_url.refresh) }.to eventually be_success
        ensure
          new_entry.delete
          expect { head(old_public_url.refresh) }.to eventually be_success
          expect { head(new_public_url.refresh).status }.to eventually eq 404
        end
      end
    end

    describe 'List' do
      it 'should list all the files' do
        iter = client.bucket('na-bucket').files
        count = 0
        iter.each_with_index do |e, i|
          expect(e.bucket_name).to eq 'na-bucket'
          expect(e.key).to eq(format('%04d', i))
          expect(e.file_size).to eq 1024
          expect(e).to be_normal_storage
          expect(e).to be_enabled
          count += 1
        end
        expect(count).to eq 2500
      end

      it 'should list part of the files' do
        iter = client.bucket('na-bucket').files limit: 1500
        count = 0
        iter.each_with_index do |e, i|
          expect(e.bucket_name).to eq 'na-bucket'
          expect(e.key).to eq(format('%04d', i))
          expect(e.file_size).to eq 1024
          expect(e).to be_normal_storage
          expect(e).to be_enabled
          count += 1
        end
        expect(count).to eq 1500
      end

      it 'should list all files started with the specified string' do
        iter = client.bucket('na-bucket').files prefix: '1'
        count = 0
        iter.each_with_index do |e, i|
          expect(e.bucket_name).to eq 'na-bucket'
          expect(e.key).to eq(format('%04d', i + 1000))
          expect(e.file_size).to eq 1024
          expect(e).to be_normal_storage
          expect(e).to be_enabled
          count += 1
        end
        expect(count).to eq 1000
      end
    end

    describe 'Fetch' do
      it 'should fetch the entry from the url' do
        src_entry = client.bucket('z1-bucket').entry('1m')
        src_url = src_entry.download_url.private
        expect(head(src_url)).to be_success
        entry = bucket.entry("16k-#{Time.now.usec}")
        begin
          dest_entry = entry.fetch_from(src_url)
          expect(dest_entry.file_size).to eq(1 << 20)
          expect(head(dest_entry.download_url.refresh)).to be_success
        ensure
          entry.try_delete
        end
      end

      it 'should fetch the entry from the url async' do
        src_entry = client.bucket('z1-bucket').entry('1m')
        src_url = src_entry.download_url.private
        expect(head(src_url)).to be_success
        entry = bucket.entry("16k-#{Time.now.usec}")
        begin
          result = entry.fetch_from(src_url, async: true)
          expect { result }.to eventually be_done
          expect(head(entry.download_url.refresh)).to be_success
        ensure
          entry.try_delete
        end
      end
    end
  end

  describe QiniuNg::Storage::BatchOperations do
    client = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
    end

    it 'should get all stats of a bucket' do
      files = %w[4k 16k 1m].freeze
      batch = client.bucket('z0-bucket').batch
      files.each do |file|
        batch = batch.stat(file)
      end
      results = batch.do
      expect(results.select(&:success?).size).to eq files.size
      expect(results.reject(&:success?).size).to be_zero
      expect(results.map { |result| result.response.file_size }).to eq(
        [4 * (1 << 10), 16 * (1 << 10), 1 * (1 << 20)]
      )
    end

    it 'should do batch operations more than limits' do
      size = (QiniuNg::Config.batch_max_size * 2.5).to_i
      batch = client.bucket('z0-bucket').batch
      size.times do
        batch = batch.stat('16k')
      end
      expect(batch.do.size).to eq size
    end
  end

  describe QiniuNg::Storage::PublicURL do
    entry = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      entry = client.bucket('z0-bucket').entry('1m')
    end

    it 'should access entry by public url' do
      expect(head(entry.download_url)).to be_success
    end

    it 'should set fop' do
      expect(head(entry.download_url.set(fop: 'qhash/md5'))).to be_success
    end

    it 'should set filename' do
      expect(entry.download_url.set(filename: 'test.bin')).to be_include('attname=test.bin')
    end
  end

  describe QiniuNg::Storage::PrivateURL do
    entry = nil

    before :all do
      client = QiniuNg::Client.new(access_key: access_key, secret_key: secret_key)
      entry = client.bucket('z1-bucket').entry('1m')
    end

    it 'should not access entry by public url' do
      expect(head(entry.download_url).status).to eq 401
    end

    it 'should access entry by private url' do
      expect(head(entry.download_url.private)).to be_success
    end
  end
end
