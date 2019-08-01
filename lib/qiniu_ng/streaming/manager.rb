# frozen_string_literal: true

module QiniuNg
  module Streaming
    # 七牛直播管理
    #
    # 该类所有方法都已被委托给 QiniuNg::Client 直接调用
    class Manager
      # @!visibility private
      def initialize(http_client_v2, auth, bucket_manager)
        @http_client_v2 = http_client_v2
        @auth = auth
        @bucket_manager = bucket_manager
      end

      # 获取一个直播空间
      #
      # @param [String] hub_name 空间名称
      # @param [String] domain 空间域名
      # @param [String] bucket_name 绑定的存储空间名称
      # @return [Hub] 返回一个七牛直播空间
      def hub(hub_name, domain:, bucket_name:)
        Hub.new(hub_name, @http_client_v2, @auth, domain, @bucket_manager.bucket(bucket_name))
      end
    end
  end
end
