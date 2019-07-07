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
    results = client.cdn_refresh(urls: urls)
    expect(results.size).to eq 1
    result = results.values.first
    expect(result).to be_ok
    expect(result.description).to eq 'success'
    expect(result.invalid_urls).to be_empty
    expect(result.invalid_prefixes).to be_empty
    expect(result.urls_quota_perday).to be > 0
    expect(result.urls_surplus_today).to be > 0
    expect(result.prefixes_quota_perday).to be > 0
    expect(result.prefixes_surplus_today).to be > 0

    processing = 0
    successful = 0
    result.query.only_processing.each do |query_result|
      expect(query_result.state).to eq 'processing'
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      processing += 1
    end
    result.query.only_successful.each do |query_result|
      expect(query_result.state).to eq 'success'
      expect(entry_names.any? { |entry_name| query_result.url.end_with?(entry_name) }).to be true
      successful += 1
    end
    expect(result.query.only_failed.to_a).to be_empty
    expect(processing + successful).to be >= 3
  end

  it 'should prefetch 3 urls' do
    paths = 3.times.map { create_temp_file(kilo_size: 16) }
    entries = 3.times.map { bucket.entry("16k-#{Time.now.usec}") }
    begin
      entries.each_with_index do |entry, i|
        bucket.upload(filepath: paths[i], upload_token: entry.upload_token)
      end
      results = client.cdn_prefetch(entries.map(&:download_url))
      expect(results.size).to eq 1
      result = results.values.first
      expect(result).to be_ok
      processing = 0
      successful = 0
      result.query.only_processing.each do |query_result|
        expect(query_result.state).to eq 'processing'
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        processing += 1
      end
      result.query.only_successful.each do |query_result|
        expect(query_result.state).to eq 'success'
        expect(entries.any? { |entry| query_result.url.end_with?(entry.key) }).to be true
        successful += 1
      end
      expect(result.query.only_failed.to_a).to be_empty
      expect(processing + successful).to be >= 3
    ensure
      bucket.batch.tap { |b| entries.each { |entry| b.delete(entry.key) } }.do
    end
  end
end
