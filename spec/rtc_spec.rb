# frozen_string_literal: true

RSpec.describe QiniuNg::RTC do
  client = nil
  hub = nil

  before :all do
    client = QiniuNg.new_client(access_key: access_key, secret_key: secret_key)
    hub = client.hub('avr-pili', domain: 'avr-zhourong.qiniu-solutions.com', bucket_name: 'avr-pili')
  end

  it 'should create / update / get / delete a new app' do
    begin
      app = hub.create_rtc_app(title: 'test', max_users: 10)
      expect(app.title).to eq 'test'
      expect(app.hub).to eq 'avr-pili'
      expect(app.max_users).to eq 10
      expect(app.created_at).to be_within(60).of(Time.now)
      expect(app.updated_at).to be_within(60).of(Time.now)
      expect(app).to be_auto_kick

      app = client.rtc_app(app.id)
      expect(app.title).to eq 'test'
      expect(app.hub).to eq 'avr-pili'
      expect(app.max_users).to eq 10
      expect(app.created_at).to be_within(60).of(Time.now)
      expect(app.updated_at).to be_within(60).of(Time.now)
      expect(app).to be_auto_kick

      app.update(title: 'new-test', max_users: 30, auto_kick: false)
      expect(app.title).to eq 'new-test'
      expect(app.hub).to eq 'avr-pili'
      expect(app.max_users).to eq 30
      expect(app.created_at).to be_within(60).of(Time.now)
      expect(app.updated_at).to be_within(60).of(Time.now)
      expect(app).not_to be_auto_kick

      app = client.rtc_app(app.id)
      expect(app.title).to eq 'new-test'
      expect(app.hub).to eq 'avr-pili'
      expect(app.max_users).to eq 30
      expect(app.created_at).to be_within(60).of(Time.now)
      expect(app.updated_at).to be_within(60).of(Time.now)
      expect(app).not_to be_auto_kick
    ensure
      app&.delete
      expect { client.rtc_app(app.id) }.to raise_error(QiniuNg::HTTP::ResourceNotFound)
    end
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

    it 'should list 200 users' do
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { appId: 'abcdef', hub: 'avr-pili', title: '', noAutoKickUser: false,
                           createdAt: Time.now, updatedAt: Time.now }.to_json)
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef/rooms/xyz/users')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { users: (1..200).each.map { |i| { userId: i } } }.to_json)
      users = client.rtc_app('abcdef').room('xyz').list_users
      expect(users.size).to eq 200
      (1..200).each_with_index { |id, i| expect(users[i].id).to eq id }
    end

    it 'should kick the user' do
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { appId: 'abcdef', hub: 'avr-pili', title: '', noAutoKickUser: false,
                           createdAt: Time.now, updatedAt: Time.now }.to_json)
      stub_request(:delete, 'http://rtc.qiniuapi.com/v3/apps/abcdef/rooms/xyz/users/3')
      client.rtc_app('abcdef').room('xyz').kick_user(3)
    end

    it 'should stop the merge' do
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { appId: 'abcdef', hub: 'avr-pili', title: '', noAutoKickUser: false,
                           createdAt: Time.now, updatedAt: Time.now }.to_json)
      stub_request(:delete, 'http://rtc.qiniuapi.com/v3/apps/abcdef/rooms/xyz/merge')
      client.rtc_app('abcdef').room('xyz').stop_merge
    end

    it 'should list 1500 rooms' do
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { appId: 'abcdef', hub: 'avr-pili', title: '', noAutoKickUser: false,
                           createdAt: Time.now, updatedAt: Time.now }.to_json)
      app = client.rtc_app('abcdef')
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef/rooms')
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { end: false, offset: 1000, rooms: (1..1000).each.map { |i| "room-#{i}" } }.to_json)
      stub_request(:get, 'http://rtc.qiniuapi.com/v3/apps/abcdef/rooms')
        .with(query: { offset: '1000' })
        .to_return(headers: { 'Content-Type': 'application/json' },
                   body: { end: true, offset: 1500, rooms: (1001..1500).each.map { |i| "room-#{i}" } }.to_json)
      room_names = app.active_rooms.map(&:name).to_a
      expect(room_names.size).to eq 1500
      (1..1500).each { |i| expect(room_names).to be_include("room-#{i}") }
    end
  end
end
