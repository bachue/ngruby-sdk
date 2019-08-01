# frozen_string_literal: true

RSpec.describe QiniuNg::Processing do
  client = nil
  bucket = nil

  before :all do
    client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
    bucket = client.bucket('z0-bucket')
  end

  it 'should process file by pfop' do
    target_entry = bucket.entry('test-video.jpg')
    begin
      id = bucket.entry('test-video.mp4')
                 .pfop("vframe/jpg/offset/1|saveas/#{target_entry.encode}", pipeline: 'sdktest')
      expect { id }.to eventually be_done
      results = id.get
      expect(results).to be_ok
      expect(results.status).to eq :ok
      expect(results.size).to eq 1
      result = results.first
      expect(result).to be_ok
      expect(result.status).to eq :ok
      expect(result.cmd).to eq "vframe/jpg/offset/1|saveas/#{target_entry.encode}"
      expect(result.description).to be_nil
      expect(result.error).to be_nil
      expect(result.keys).to eq %w[test-video.jpg]
      expect(result.key).to eq 'test-video.jpg'
    ensure
      target_entry.try_delete
    end
  end

  it 'should process files by pfop and query results by id' do
    target_entries = (1..3).each.map { |i| bucket.entry("test-video-#{i}.png") }
    begin
      id = bucket.entry('test-video.mp4')
                 .pfop(["vframe/png/offset/1|saveas/#{target_entries[0].encode}",
                        "vframe/png/offset/2|saveas/#{target_entries[1].encode}",
                        "vframe/png/offset/3|saveas/#{target_entries[2].encode}"],
                       pipeline: 'sdktest')
                 .to_s
      expect { bucket.query_processing_result(id) }.to eventually be_done
      results = bucket.query_processing_result(id)
      expect(results).to be_ok
      expect(results.status).to eq :ok
      expect(results.size).to eq 3

      results.each_with_index do |result, i|
        expect(result).to be_ok
        expect(result.status).to eq :ok
        expect(result.cmd).to eq "vframe/png/offset/#{i + 1}|saveas/#{target_entries[i].encode}"
        expect(result.description).to be_nil
        expect(result.error).to be_nil
        expect(result.keys).to eq ["test-video-#{i + 1}.png"]
        expect(result.key).to eq "test-video-#{i + 1}.png"
      end
    ensure
      target_entries.each(&:try_delete)
    end
  end
end
