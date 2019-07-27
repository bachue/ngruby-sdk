# frozen_string_literal: true

module QiniuNg
  module RTC
    # 七牛实时音视频连麦房间
    #
    # @!attribute [r] app
    #   @return [App] RTC 应用
    # @!attribute [r] name
    #   @return [String] 房间名称
    class Room
      attr_reader :app, :name

      # @!visibility private
      def initialize(app, name, http_client_v2, auth)
        @app = app
        @name = name
        @http_client_v2 = http_client_v2
        @auth = auth
      end

      # 列出当前房间下当前所有用户
      #
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用
      # @return [Array<User>] 返回用户列表
      def list_users(rtc_url: nil, https: nil, **options)
        resp_body = @http_client_v2.get("/v3/apps/#{@app.id}/rooms/#{@name}/users",
                                        rtc_url || get_rtc_url(https), **options).body
        resp_body['users'].map { |item| User.new(item, self) }.freeze
      end

      # 房间用户
      # @!attribute [r] user_id
      #   @return [String] 用户 ID
      class User
        attr_reader :user_id

        # @!visibility private
        def initialize(hash, room)
          @user_id = hash['userId']
          @room = room
        end
        alias id user_id

        # 将该用户踢出房间
        # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用或用户
        # @raise [QiniuNg::HTTP::RoomIsNotActive] RTC 房间不存在
        def kick(rtc_url: nil, https: nil, **options)
          @room.kick_user(@user_id, rtc_url: rtc_url, https: https, **options)
        end

        # @!visibility private
        def inspect
          "#<#{self.class.name} @user_id=#{@user_id.inspect}>"
        end
      end

      # 将指定该用户踢出房间
      # @param [String] user_id 用户 ID
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用或用户
      # @raise [QiniuNg::HTTP::RoomIsNotActive] RTC 房间不存在
      def kick_user(user_id, rtc_url: nil, https: nil, **options)
        @http_client_v2.delete("/v3/apps/#{@app.id}/rooms/#{@name}/users/#{user_id}",
                               rtc_url || get_rtc_url(https), **options)
        nil
      end

      # 停止当前房间的合流转推
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到应用
      # @raise [QiniuNg::HTTP::RoomIsNotActive] RTC 房间不存在
      def stop_merge(rtc_url: nil, https: nil, **options)
        @http_client_v2.delete("/v3/apps/#{@app.id}/rooms/#{@name}/merge",
                               rtc_url || get_rtc_url(https), **options)
        nil
      end

      private

      def get_rtc_url(https)
        Common::Zone.rtc_url(https)
      end
    end
  end
end
