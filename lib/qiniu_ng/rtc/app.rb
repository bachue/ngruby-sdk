# frozen_string_literal: true

module QiniuNg
  module RTC
    # 七牛实时音视频应用
    #
    # @!attribute [r] app_id
    #   @return [String] RTC 应用 ID
    # @!attribute [r] hub
    #   @return [String] 绑定的直播空间名称
    # @!attribute [r] title
    #   @return [String] RTC 应用名称，该名称并非唯一标识符
    # @!attribute [r] max_users
    #   @return [Integer] 连麦房间支持的最大在线人数
    # @!attribute [r] created_at
    #   @return [Time] 应用创建时间
    # @!attribute [r] updated_at
    #   @return [Time] 应用修改时间
    # @!attribute [r] auto_kick
    #   @return [Boolean] 是否启用自动踢人。
    #     表示同一个身份的客户端，一旦新的连麦请求可以成功，旧连接将被关闭
    # @!attribute [r] merge_publish_rtmp_config
    #   @return [MergePublishRTMPConfig] 连麦合流转推 RTMP 的配置
    class App
      attr_reader :app_id, :hub, :title, :max_users, :created_at, :updated_at, :auto_kick,
                  :merge_publish_rtmp_config
      alias id app_id

      # @!visibility private
      def initialize(hash, http_client_v2, auth)
        assign_attributes(hash)
        @http_client_v2 = http_client_v2
        @auth = auth
      end
      alias auto_kick? auto_kick

      # 连麦合流转推 RTMP 的配置
      #
      # @!attribute [r] enabled
      #   @return [Boolean] 开启和关闭所有房间的合流功能
      # @!attribute [r] audio_only
      #   @return [Boolean] 指定是否只合成音频
      # @!attribute [r] height
      #   @return [Integer] 合流输出画面的高度
      # @!attribute [r] width
      #   @return [Integer] 合流输出画面的宽度
      # @!attribute [r] fps
      #   @return [Integer] 合流输出的帧率
      # @!attribute [r] kbps
      #   @return [Integer] 合流输出的码率
      # @!attribute [r] url
      #   @return [String] 合流后转推旁路直播的地址
      # @!attribute [r] stream_title
      #   @return [String] 转推七牛直播云的流名
      class MergePublishRTMPConfig
        attr_reader :enabled, :audio_only, :width, :height, :fps, :kbps, :url, :stream_title
        # @!visibility private
        def initialize(hash)
          @enabled = hash['enable']
          @audio_only = Utils::Bool.to_bool(hash['audioOnly'])
          @height = hash['height']
          @width = hash['width']
          @fps = hash['fps']
          @kbps = hash['kbps']
          @url = hash['url']
          @stream_title = hash['streamTitle']
        end
        alias enabled? enabled
        alias audio_only? audio_only
      end

      # 修改应用
      #
      # @param [String] hub 绑定的直播空间
      # @param [String] title RTC 应用名称
      # @param [Integer] max_users 连麦房间支持的最大在线人数
      # @param [Boolean] auto_kick 是否启用自动踢人。
      #   表示同一个身份的客户端，一旦新的连麦请求可以成功，旧连接将被关闭
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用
      # @raise [QiniuNg::HTTP::HubNotMatch] 应用和直播空间不匹配
      # @return [App] 返回 RTC 应用
      def update(hub: nil, title: nil, max_users: nil, auto_kick: nil, rtc_url: nil, https: nil, **options)
        params = { hub: hub, title: title, maxUsers: max_users }.compact
        params['noAutoKickUser'] = !auto_kick unless auto_kick.nil?
        resp_body = @http_client_v2.post("/v3/apps/#{@app_id}", rtc_url || get_rtc_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(params),
                                         **options).body
        assign_attributes(resp_body)
        self
      end

      # 删除应用
      #
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用
      # @return [App] 返回 RTC 应用
      def delete(rtc_url: nil, https: nil, **options)
        @http_client_v2.delete("/v3/apps/#{@app_id}", rtc_url || get_rtc_url(https), **options)
        nil
      end

      # 获取一个 RTC 房间
      #
      # @param [String] name 房间名称
      # @return [Room] 返回 RTC 房间
      def room(name)
        Room.new(self, name, @http_client_v2, @auth)
      end

      # 获取当前所有活跃的房间
      #
      # @param [String] prefix 房间名称前缀
      # @param [Integer] offset 分页查询的位移标记
      # @param [Integer] limit 查询房间数量最大上限
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用
      # @return [Enumerable] 返回一个{迭代器}[https://ruby-doc.org/core-2.6/Enumerable.html]实例
      def active_rooms(prefix: nil, offset: nil, limit: nil, rtc_url: nil, https: nil, **options)
        RoomsIterator.new(@http_client_v2, @auth, self, prefix, limit, offset,
                          rtc_url || get_rtc_url(https), options)
      end

      # @!visibility private
      class RoomsIterator
        include Enumerable

        # @!visibility private
        def initialize(http_client, auth, app, prefix, limit, offset, list_url, options)
          @http_client = http_client
          @auth = auth
          @app = app
          @prefix = prefix
          @limit = limit
          @got = 0
          @offset = offset
          @list_url = list_url
          @options = options
        end

        # @!visibility private
        def each
          return enumerator unless block_given?

          enumerator.each do |entry|
            yield entry
          end
        end

        private

        def enumerator
          Enumerator.new do |yielder|
            loop do
              params = {}
              params[:prefix] = @prefix unless @prefix.nil? || @prefix.empty?
              params[:limit] = @limit unless @limit.nil? || !@limit.positive?
              params[:offset] = @offset unless @offset.nil?
              body = @http_client.get("/v3/apps/#{@app.id}/rooms", @list_url, params: params, **@options).body
              @offset = body['offset']
              break if body['rooms'].size.zero?

              body['rooms'].each do |room_name|
                break unless @limit.nil? || @got < @limit

                yielder << Room.new(@app, room_name, @http_client, @auth)
                @got += 1
              end
              break if body['end'] || !@limit.nil? && @got >= @limit
            end
          end
        end
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} @app_id=#{@app_id.inspect} @title=#{@title.inspect} @hub=#{@hub.inspect}>"
      end

      private

      def assign_attributes(hash)
        @app_id = hash['appId']
        @title = hash['title']
        @hub = hash['hub']
        @max_users = hash['maxUsers']
        @auto_kick = !hash['noAutoKickUser']
        if hash.key?('mergePublishRtmp')
          @merge_publish_rtmp_config = MergePublishRTMPConfig.new(hash['mergePublishRtmp'])
        end
        @created_at = Time.parse(hash['createdAt']) if hash.key?('createdAt')
        @updated_at = Time.parse(hash['updatedAt']) if hash.key?('updatedAt')
      end

      def get_rtc_url(https)
        Common::Zone.rtc_url(https)
      end
    end
  end
end
