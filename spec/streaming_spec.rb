# frozen_string_literal: true

require 'securerandom'

RSpec.describe QiniuNg::Streaming do
  client = nil
  hub = nil

  before :all do
    client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
    hub = client.hub('avr-pili', domain: 'avr-zhourong.qiniu-solutions.com')
  end

  it 'should create 10 streams and list them' do
    (1..10).each do |i|
      stream = hub.create_stream("stream-#{i}-#{SecureRandom.hex(4)}")
      expect(stream.attributes.created_at).to be_within(5).of(Time.now)
      expect(stream.attributes.updated_at).to be_within(5).of(Time.now)
      stream.disable
      expect(stream.attributes(refresh: true)).to be_disabled
      expect(stream.attributes(refresh: true)).to be_disabled_forever
      stream.enable
      expect(stream.attributes(refresh: true)).to be_enabled
    end
    stream_keys = hub.streams(prefix: 'stream-').map(&:key).to_a
    (1..10).each do |i|
      expect(stream_keys).to(be_any { |key| key.start_with?("stream-#{i}") })
    end
  end

  it 'should return nil when try to get live_info from a new stream' do
    stream = hub.create_stream("stream-#{SecureRandom.hex(4)}")
    expect(stream.live_info).to be_nil
  end

  describe do
    before :all do
      WebMock.enable!
    end

    after :all do
      WebMock.disable!
    end

    after :each do
      WebMock.reset!
    end

    it 'should list 1500 streams' do
      stub_request(:get, "http://pili.qiniuapi.com/v2/hubs/#{hub.name}/streams")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { items: (1..1000).each.map { |i| { key: "stream-#{i}" } }, marker: 'abcdef' }.to_json)
      stub_request(:get, "http://pili.qiniuapi.com/v2/hubs/#{hub.name}/streams")
        .with(query: { marker: 'abcdef' })
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { items: (1001..1500).each.map { |i| { key: "stream-#{i}" } }, marker: '' }.to_json)
      stream_keys = hub.streams.map(&:key).to_a
      expect(stream_keys.size).to eq 1500
      (1..1500).each { |i| expect(stream_keys).to be_include("stream-#{i}") }
    end

    it 'should return live info' do
      stub_request(:get, "http://pili.qiniuapi.com/v2/hubs/#{hub.name}/streams/#{Base64.urlsafe_encode64('stream')}/live")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: {
                     startAt: 1_463_577_162, clientIP: '172.21.1.106:53349',
                     bps: 73_827, fps: { audio: 38, video: 23, data: 0 }
                   }.to_json)
      live_info = hub.stream('stream').live_info
      expect(live_info.started_at).to eq Time.at(1_463_577_162)
      expect(live_info.client_ip).to eq '172.21.1.106:53349'
      expect(live_info.bps).to eq 73_827
      expect(live_info.fps['audio']).to eq 38
      expect(live_info.fps['video']).to eq 23
      expect(live_info.fps['data']).to eq 0
    end

    it 'should return live info of multiple streams' do
      stub_request(:post, "http://pili.qiniuapi.com/v2/hubs/#{hub.name}/livestreams")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: {
                     items: [{
                       key: 'stream1', startAt: 1_463_577_162, clientIP: '172.21.1.106:53349',
                       bps: 73_827, fps: { audio: 38, video: 23, data: 0 }
                     }]
                   }.to_json)
      live_info = hub.live_info('stream1', 'stream2')
      expect(live_info['stream1'].started_at).to eq Time.at(1_463_577_162)
      expect(live_info['stream1'].client_ip).to eq '172.21.1.106:53349'
      expect(live_info['stream1'].bps).to eq 73_827
      expect(live_info['stream1'].fps['audio']).to eq 38
      expect(live_info['stream1'].fps['video']).to eq 23
      expect(live_info['stream1'].fps['data']).to eq 0
      expect(live_info).not_to have_key('stream2')
    end

    it 'should return get history activities' do
      stub_request(:get, "http://pili.qiniuapi.com/v2/hubs/#{hub.name}/streams/#{Base64.urlsafe_encode64('stream')}/historyactivity")
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { items: [{ start: 1_463_577_162, end: 1_463_577_171 }, { start: 1_463_382_401, end: 1_463_382_793 }] }.to_json)
      activities = hub.stream('stream').history_activities
      expect(activities.size).to eq 2
      expect(activities[0].first).to eq Time.at(1_463_577_162)
      expect(activities[0].last).to eq Time.at(1_463_577_171)
      expect(activities[1].first).to eq Time.at(1_463_382_401)
      expect(activities[1].last).to eq Time.at(1_463_382_793)
    end

    it 'should generate urls' do
      stream = hub.stream('stream')
      expect(stream.rtmp_publish_url).to(
        eq 'rtmp://pili-publish.avr-zhourong.qiniu-solutions.com/avr-pili/stream'
      )
      expect(stream.rtmp_publish_url.private).to(
        be_start_with('rtmp://pili-publish.avr-zhourong.qiniu-solutions.com/avr-pili/stream?e=')
      )
      expect(stream.rtmp_play_url).to(
        eq 'rtmp://pili-live-rtmp.avr-zhourong.qiniu-solutions.com/avr-pili/stream'
      )
      expect(stream.hls_play_url).to(
        eq 'http://pili-live-hls.avr-zhourong.qiniu-solutions.com/avr-pili/stream.m3u8'
      )
      expect(stream.hdl_play_url).to(
        eq 'http://pili-live-hdl.avr-zhourong.qiniu-solutions.com/avr-pili/stream.flv'
      )
      expect(stream.snapshot_url).to(
        eq 'http://pili-snapshot.avr-zhourong.qiniu-solutions.com/avr-pili/stream.jpg'
      )
    end
  end
end
