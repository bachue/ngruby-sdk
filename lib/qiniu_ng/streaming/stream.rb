# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Streaming
    # 七牛直播流
    #
    # @!attribute [r] hub
    #   @return [Hub] 直播空间
    # @!attribute [r] key
    #   @return [String] 直播流名称
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

      # 获取直播流详细信息
      #
      # @param [Boolean] refresh 是否强制刷新缓存。如果为 false 或不填写，则尽量使用缓存中的数据
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @return [Attributes] 返回直播流详细信息
      def attributes(refresh: false, pili_url: nil, https: nil, **options)
        @attributes = nil if refresh
        @attributes ||= begin
                          path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}"
                          resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), **options).body
                          Attributes.new(resp_body)
                        end
      end

      # 直播流详细信息
      # @!attribute [r] created_at
      #   @return [Time] 直播流创建时间
      # @!attribute [r] updated_at
      #   @return [Time] 直播流修改时间
      # @!attribute [r] expire_at
      #   @return [Time] 直播流过期时间
      class Attributes
        attr_reader :created_at, :updated_at, :expire_at

        # @!visibility private
        def initialize(hash)
          @created_at = Time.at(hash['createdAt'])
          @updated_at = Time.at(hash['updatedAt'])
          @expire_at = Time.at(hash['expireAt'])
          @disabled_till = hash['disabledTill']
        end

        # 直播流解禁时间
        #
        # @return [Time, nil] 返回直播流解禁时间。如果直播流并未被禁播，则返回 nil
        def disabled_until
          Time.at(@disabled_till) if @disabled_till.positive?
        end

        # 直播流是否已经禁用
        #
        # @return [Boolean] 返回是否已经禁用
        def disabled?
          !enabled?
        end

        # 直播流是否未被禁用
        #
        # @return [Boolean] 返回是否未被禁用
        def enabled?
          @disabled_till.zero?
        end

        # 直播流是否被永久禁用
        #
        # @return [Boolean] 直播流是否被永久禁用
        def disabled_forever?
          @disabled_till.negative?
        end
      end

      # 解除禁播流
      #
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      def enable(pili_url: nil, https: nil, **options)
        disable(recover_until: 0, pili_url: pili_url, https: https, **options)
      end

      # 禁播流
      #
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      def disable(recover_until: -1, pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/disabled"
        @http_client_v2.post(path, pili_url || get_pili_url(https),
                             headers: { content_type: 'application/json' },
                             body: Config.default_json_marshaler.call(disabledTill: recover_until.to_i),
                             **options)
        nil
      end

      # 获取直播流实时信息
      #
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @return [LiveInfo, nil] 返回直播流实时信息，如果该直播流并未处于直播状态，则返回 nil
      def live_info(pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/live"
        resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), **options).body
        LiveInfo.new(resp_body)
      rescue HTTP::NoData
        nil
      end

      # 直播实时信息
      # @!attribute [r] started_at
      #   @return [Time] 直播流开始直播时间
      # @!attribute [r] client_ip
      #   @return [String] 主播的 IP 地址
      # @!attribute [r] bps
      #   @return [Integer] 当前码率
      # @!attribute [r] fps
      #   @return [LiveInfo::FPS] 返回帧率信息
      class LiveInfo
        attr_reader :started_at, :client_ip, :bps, :fps

        # @!visibility private
        def initialize(hash)
          @started_at = Time.at(hash['startAt']).freeze
          @client_ip = hash['clientIP'].freeze
          @bps = hash['bps']
          @fps = FPS.new(hash['fps']).freeze
        end

        # 帧率信息
        # @!attribute [r] audio
        #   @return [Integer] 音频帧率
        # @!attribute [r] video
        #   @return [Integer] 视频帧率
        # @!attribute [r] data
        #   @return [Integer] 数据帧率
        class FPS
          attr_reader :audio, :video, :data

          # @!visibility private
          def initialize(hash)
            @audio = hash['audio']
            @video = hash['video']
            @data = hash['data']
          end
        end
      end

      # 获取直播历史记录
      #
      # @param [Time] from 查询起始时间，如果为 nil 或不填，则表示不限制起始时间
      # @param [Time] to 查询结束时间，如果为 nil 或不填，则表示当前时间
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @return [Array<Array<Time>>] 返回一个列表，每个列表中包含一个仅有两个时间的数组，分别表示直播起始时间和结束时间。
      def history_activities(from: nil, to: nil, pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/historyactivity"
        params = {}
        params['start'] = from.to_i if from&.to_i&.> 0
        params['end'] = to.to_i if to&.to_i&.> 0
        resp_body = @http_client_v2.get(path, pili_url || get_pili_url(https), params: params, **options).body
        resp_body['items'].map { |item| [Time.at(item['start']), Time.at(item['end'])].freeze }.freeze
      end

      # 录制直播回放
      #
      # @param [String] key 保存的文件名，不指定系统会随机生成
      # @param [Time] from 要保存的直播的起始时间，如果为 nil 或不填，则表示不限制起始时间
      # @param [Time] to 要保存的直播的结束时间，如果为 nil 或不填，则表示当前时间
      # @param [Symbol, String] format 保存的文件格式，默认为 m3u8，如果需要指定其他格式，将会启用异步处理
      # @param [String] pipeline 当使用异步处理时，使用的数据处理私有队列名称
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-persistentPipeline]
      # @param [String] notify_url 当使用异步处理时，保存成功回调通知地址
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#putpolicy-persistentNotifyUrl]
      # @param [Integer] expire_after_days 文件生命周期，单位为天。默认永久保存
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @raise [QiniuNg::HTTP::NoData] 该时间点上没有直播数据
      # @return [SaveAsResult] 返回录制结果
      def save_as(key: nil, from: nil, to: nil, format: :m3u8,
                  pipeline: nil, notify_url: nil, expire_after_days: nil,
                  pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/saveas"
        req_body = {
          fname: key, start: from&.to_i, to: to&.to_i, format: format,
          pipeline: pipeline, notify: notify_url, expireDays: expire_after_days
        }.compact
        resp_body = @http_client_v2.post(path, pili_url || get_pili_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(req_body),
                                         **options).body
        SaveAsResult.new(resp_body).freeze
      end
      alias saveas save_as

      # 录制直播回放结果
      #
      # @!attribute [r] key
      #   @return [String] 保存后在存储空间里的文件名
      # @!attribute [r] persistent_id
      #   @return [String] 持久化异步处理任务 ID
      class SaveAsResult
        attr_reader :key, :persistent_id

        # @!visibility private
        def initialize(hash)
          @key = hash['fname']
          @persistent_id = hash['persistentID']
        end
      end

      # 保存直播截图
      #
      # @param [String] key 保存的文件名，不指定系统会随机生成
      # @param [Time] time 要保存截图的时间点，如果为 nil 或不填，则表示不限制起始时间
      # @param [String, Symbol] format 要保存的文件格式，默认为 JPG
      # @param [Integer] expire_after_days 文件生命周期，单位为天。默认永久保存
      # @param [Integer] delete_after_days 与 expire_after_days 语义相同。仅使用任意一个参数即可，不必同时使用
      # @param [String] pili_url Pili 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @raise [Faraday::ClientError] 该时间点上没有视频
      # @return [SnapshotResult] 返回录制结果
      def snapshot(key: nil, time: nil, format: :jpg, expire_after_days: nil, delete_after_days: nil,
                   pili_url: nil, https: nil, **options)
        path = "/v2/hubs/#{@hub.name}/streams/#{Base64.urlsafe_encode64(@key)}/snapshot"
        req_body = {
          fname: key, time: time&.to_i, format: format, deleteAfterDays: delete_after_days || expire_after_days
        }.compact
        resp_body = @http_client_v2.post(path, pili_url || get_pili_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(req_body),
                                         **options).body
        SnapshotResult.new(resp_body).freeze
      end

      # 保存直播截图结果
      #
      # @!attribute [r] key
      #   @return [String] 保存后在存储空间里的文件名
      class SnapshotResult
        attr_reader :key

        # @!visibility private
        def initialize(hash)
          @key = hash['fname']
        end
      end

      # RTMP 推流域名
      #
      # @return [String] RTMP 推流域名
      def rtmp_publish_domain
        "pili-publish.#{@domain}"
      end

      # RTMP 播放域名
      #
      # @return [String] RTMP 播放域名
      def rtmp_play_domain
        "pili-live-rtmp.#{@domain}"
      end

      # HLS 播放域名
      #
      # @return [String] HLS 播放域名
      def hls_play_domain
        "pili-live-hls.#{@domain}"
      end

      # HDL (HTTP-FLV) 播放域名
      #
      # @return [String] HDL (HTTP-FLV) 播放域名
      def hdl_play_domain
        "pili-live-hdl.#{@domain}"
      end

      # 直播封面域名
      #
      # @return [String] 直播封面域名
      def snapshot_domain
        "pili-snapshot.#{@domain}"
      end

      # RTMP 推流地址
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   url = client.hub('<Hub Name>', domain: '<Hub Domain>').stream('<Stream Key>').rtmp_publish_url
      #
      # @return [URL::RTMPPublishURL] RTMP 推流地址
      def rtmp_publish_url
        URL::RTMPPublishURL.new(rtmp_publish_domain, @hub.name, @key, @auth)
      end

      # RTMP 播放地址
      #
      # @return [PlayURL] RTMP 播放地址
      def rtmp_play_url
        URL::PlayURL.new('rtmp', rtmp_play_domain, @hub.name, @key)
      end

      # HLS 播放地址
      #
      # @return [URL::PlayURL] HLS 播放地址
      def hls_play_url
        URL::PlayURL.new('http', hls_play_domain, @hub.name, "#{@key}.m3u8")
      end

      # HDL (HTTP-FLV) 播放地址
      #
      # @return [URL::PlayURL] HDL (HTTP-FLV) 播放地址
      def hdl_play_url
        URL::PlayURL.new('http', hdl_play_domain, @hub.name, "#{@key}.flv")
      end

      # 直播封面地址
      #
      # @return [URL::PlayURL] 直播封面地址
      def snapshot_url
        URL::PlayURL.new('http', snapshot_domain, @hub.name, "#{@key}.jpg")
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
