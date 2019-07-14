# frozen_string_literal: true

RSpec.describe QiniuNg::CDN do
  client = nil
  bucket = nil

  before :all do
    client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
    bucket = client.bucket('z0-bucket')
  end

  it 'should refresh 3 urls' do
    entry_names = %w[4k 16k 1m]
    urls = entry_names.map { |entry_name| bucket.entry(entry_name).download_url }
    requests = client.cdn_refresh(urls: urls)
    expect(requests.size).to eq 1
    request = requests.values.first
    expect(request).to be_ok
    expect(request.description).to eq 'success'
    expect(request.invalid_urls).to be_empty
    expect(request.invalid_prefixes).to be_empty
    expect(request.urls_quota_perday).to be > 0
    expect(request.urls_surplus_today).to be > 0
    expect(request.prefixes_quota_perday).to be > 0
    expect(request.prefixes_surplus_today).to be > 0

    processing = 0
    successful = 0
    request.results.only_processing.each do |query_result|
      expect(query_result).to be_processing
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      processing += 1
    end
    request.results.only_successful.each do |query_result|
      expect(query_result).to be_successful
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      successful += 1
    end
    expect(request.results.only_failed.to_a).to be_empty
    expect(processing + successful).to be >= 3

    processing = 0
    successful = 0
    request_id = request.id
    client.query_cdn_refresh_results(request_id).each do |query_result|
      expect(query_result).to be_processing
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      processing += 1
    end
    client.query_cdn_refresh_results(request_id).only_successful.each do |query_result|
      expect(query_result).to be_successful
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      successful += 1
    end
    expect(client.query_cdn_refresh_results(request_id).only_failed.to_a).to be_empty
    expect(processing + successful).to be >= 3
  end

  it 'should prefetch 3 urls' do
    paths = 3.times.map { create_temp_file(kilo_size: 16) }
    entries = 3.times.map { bucket.entry("16k-#{Time.now.usec}") }
    begin
      entries.each_with_index do |entry, i|
        bucket.upload(filepath: paths[i], upload_token: entry.upload_token)
      end
      requests = client.cdn_prefetch(entries.map(&:download_url))
      expect(requests.size).to eq 1
      request = requests.values.first
      expect(request).to be_ok
      processing = 0
      successful = 0
      request.results.only_processing.each do |query_result|
        expect(query_result.state).to eq 'processing'
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        processing += 1
      end
      request.results.only_successful.each do |query_result|
        expect(query_result.state).to eq 'success'
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        successful += 1
      end
      expect(request.results.only_failed.to_a).to be_empty
      expect(processing + successful).to be >= 3

      processing = 0
      successful = 0
      request_id = request.id
      client.query_cdn_prefetch_results(request_id).each do |query_result|
        expect(query_result).to be_processing
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        processing += 1
      end
      client.query_cdn_prefetch_results(request_id).only_successful.each do |query_result|
        expect(query_result).to be_successful
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        successful += 1
      end
      expect(client.query_cdn_prefetch_results(request_id).only_failed.to_a).to be_empty
      expect(processing + successful).to be >= 3
    ensure
      bucket.batch { |b| entries.each { |e| b.delete(e.key) } }
    end
  end

  it 'should query bandwidth logs' do
    logs = client.cdn_bandwidth_log(start_time: Time.now - QiniuNg::Duration.new(days: 30).to_i, end_time: Time.now,
                                    granularity: :day, domains: 'http://z0-bucket.kodo-test.qiniu-solutions.com')
    expect(logs.times).to be_a(Array)
    expect(logs.data).to have_key('z0-bucket.kodo-test.qiniu-solutions.com')
    expect(logs.value_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com', :china)).to be_a Integer
    expect(logs.value_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com', :oversea)).to be_a Integer
    yesterday = Time.now - QiniuNg::Duration.new(days: 1).to_i
    expect(logs.value_at(yesterday, 'z0-bucket.kodo-test.qiniu-solutions.com', :china)).to be_a Integer
    expect(logs.value_at(yesterday, 'z0-bucket.kodo-test.qiniu-solutions.com', :oversea)).to be_a Integer

    expect(logs.values_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com').keys).to match_array(%w[china oversea])
    expect(logs.values_at(Time.now).keys).to match_array(%w[z0-bucket.kodo-test.qiniu-solutions.com])
  end

  it 'should query flux logs' do
    logs = client.cdn_flux_log(start_time: Time.now - QiniuNg::Duration.new(days: 30).to_i, end_time: Time.now,
                               granularity: :day, domains: ['z0-bucket.kodo-test.qiniu-solutions.com'])
    expect(logs.times).to be_a(Array)
    expect(logs.data).to have_key('z0-bucket.kodo-test.qiniu-solutions.com')
    expect(logs.value_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com', :china)).to be_a Integer
    expect(logs.value_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com', :oversea)).to be_a Integer
    yesterday = Time.now - QiniuNg::Duration.new(days: 1).to_i
    expect(logs.value_at(yesterday, 'z0-bucket.kodo-test.qiniu-solutions.com', :china)).to be_a Integer
    expect(logs.value_at(yesterday, 'z0-bucket.kodo-test.qiniu-solutions.com', :oversea)).to be_a Integer

    expect(logs.values_at(Time.now, 'z0-bucket.kodo-test.qiniu-solutions.com').keys).to match_array(%w[china oversea])
    expect(logs.values_at(Time.now).keys).to match_array(%w[z0-bucket.kodo-test.qiniu-solutions.com])
  end

  it 'should query access log files' do
    t = Time.now - QiniuNg::Duration.new(days: 30).to_i
    while t < Time.now
      logs = client.cdn_access_logs(time: t, domains: 'z0-bucket.kodo-test.qiniu-solutions.com')
      logs['z0-bucket.kodo-test.qiniu-solutions.com']&.each { |log_file| head(log_file.url) }
      t += QiniuNg::Duration.new(days: 1).to_i
    end
  end
end
