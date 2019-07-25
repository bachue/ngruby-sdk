# frozen_string_literal: true

module QiniuNg
  module Streaming
    # 七牛直播管理
    #
    # 该类所有方法都已被委托给 QiniuNg::Client 直接调用
    class Manager
      # @!visibility private
      def initialize(http_client_v2, auth)
        @http_client_v2 = http_client_v2
        @auth = auth
      end

      # 获取一个直播空间
      #
      # @param [String] hub_name 空间名称
      # @param [String] domain 空间域名
      # @return [Hub] 返回一个七牛直播空间
      def hub(hub_name, domain:)
        Hub.new(hub_name, @http_client_v2, @auth, domain)
      end
    end
  end
end
