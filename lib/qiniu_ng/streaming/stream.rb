# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Streaming
    # 七牛直播流
    class Stream
      attr_reader :hub, :key
      # @!visibility private
      def initialize(stream_key, hub, http_client_v2, auth, domain)
        @key = stream_key
        @hub = hub
        @http_client_v2 = http_client_v2
        @auth = auth
        @domain = domain
      end

      # 获取直播空间详细信息
      def attributes(refresh: false, pili_url: nil, https: nil, **options)
        @attributes = nil if refresh
        @attributes ||= begin
                          path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}"
                          resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), **options).body
                          Attributes.new(resp_body)
                        end
      end

      # 直播空间详细信息
      class Attributes
        attr_reader :created_at, :updated_at, :expire_at

        # @!visibility private
        def initialize(hash)
          @created_at = Time.at(hash['createdAt'])
          @updated_at = Time.at(hash['updatedAt'])
          @expire_at = Time.at(hash['expireAt'])
          @disabled_till = hash['disabledTill']
        end

        def disabled_until
          Time.at(@disabled_till) if @disabled_till.positive?
        end

        def disabled?
          !enabled?
        end

        def enabled?
          @disabled_till.zero?
        end

        def disabled_forever?
          @disabled_till.negative?
        end
      end

      # 解除禁播流
      def enable(pili_url: nil, https: nil, **options)
        disable(recover_until: 0, pili_url: pili_url, https: https, **options)
      end

      # 禁播流
      def disable(recover_until: -1, pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/disabled"
        @http_client_v2.post(path, pili_url || get_pili_url(https),
                             headers: { content_type: 'application/json' },
                             body: Config.default_json_marshaler.call(disabledTill: recover_until.to_i),
                             **options)
        nil
      end

      # 获取直播实时信息
      def live_info(pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/live"
        resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), **options).body
        LiveInfo.new(resp_body)
      rescue HTTP::NotLiveStream
        nil
      end

      # 直播实时信息
      class LiveInfo
        attr_reader :started_at, :client_ip, :bps, :fps

        # @!visibility private
        def initialize(hash)
          @started_at = Time.at(hash['startAt']).freeze
          @client_ip = hash['clientIP'].freeze
          @bps = hash['bps']
          @fps = hash['fps'].freeze
        end
      end

      # 获取直播历史记录
      def history_activities(from: nil, to: nil, pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/historyactivity"
        params = {}
        params['start'] = from.to_i if from&.to_i&.> 0
        params['end'] = to.to_i if to&.to_i&.> 0
        resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), params: params).body
        resp_body['items'].map { |item| [Time.at(item['start']), Time.at(item['end'])].freeze }.freeze
      end

      def rtmp_publish_domain
        "pili-publish.#{@domain}"
      end

      def rtmp_play_domain
        "pili-live-rtmp.#{@domain}"
      end

      def hls_play_domain
        "pili-live-hls.#{@domain}"
      end

      def hdl_play_domain
        "pili-live-hdl.#{@domain}"
      end

      def snapshot_domain
        "pili-snapshot.#{@domain}"
      end

      def rtmp_publish_url
        URL::RTMPPublishURL.new(rtmp_publish_domain, @hub.name, @key, @auth)
      end

      def rtmp_play_url
        URL.new('rtmp', rtmp_play_domain, @hub.name, @key)
      end

      def hls_play_url
        URL.new('http', hls_play_domain, @hub.name, "#{@key}.m3u8")
      end

      def hdl_play_url
        URL.new('http', hdl_play_domain, @hub.name, "#{@key}.flv")
      end

      def snapshot_url
        URL.new('http', snapshot_domain, @hub.name, "#{@key}.jpg")
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} @key=#{@key.inspect} hub.name=#{@hub.name.inspect}>"
      end

      private

      def get_pili_url(https)
        Common::Zone.pili_url(https)
      end
    end
  end
end
