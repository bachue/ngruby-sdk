# frozen_string_literal: true

module QiniuNg
  module RTC
    # 七牛实时音视频管理
    class Manager
      # @!visibility private
      def initialize(http_client_v2, auth)
        @http_client_v2 = http_client_v2
        @auth = auth
      end

      # 获取一个 RTC 应用
      #
      # @param [String] app_id RTC 应用 ID
      # @param [String] rtc_url RTC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::ResourceNotFound] 找不到直播流
      # @return [App] 返回 RTC 应用
      def rtc_app(app_id, rtc_url: nil, https: nil, **options)
        resp_body = @http_client_v2.get("/v3/apps/#{app_id}", rtc_url || get_rtc_url(https), **options).body
        App.new(resp_body, @http_client_v2, @auth)
      end

      private

      def get_rtc_url(https)
        Common::Zone.rtc_url(https)
      end
    end
  end
end
