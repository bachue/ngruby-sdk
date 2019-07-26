# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/processing/pfop_status'

module QiniuNg
  module Processing
    # 七牛文件处理持久化 ID
    #
    # 可用于查询持久化处理的结果
    class PersistentID < String
      extend Forwardable

      # @!visibility private
      def initialize(persistent_id, http_client_v1, bucket)
        @bucket = bucket
        @http_client_v1 = http_client_v1
        replace(persistent_id)
      end

      # 查询持久化处理的结果
      #
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [PfopResults] 返回持久化处理结果集合
      def get(api_zone: nil, https: nil, **options)
        resp_body = @http_client_v1.get('/status/get/prefop', get_api_url(@bucket, api_zone, https),
                                        params: { id: to_s }, **options).body
        PfopResults.new(resp_body)
      end

      # @!method done?
      #   数据处理是否已经结束
      #   @return [Boolean] 数据处理是否已经结束
      # @!method ok?
      #   数据处理是否已经成功
      #   @return [Boolean] 数据处理是否已经成功
      # @!method pending?
      #   数据处理请求是否在排队中
      #   @return [Boolean] 数据处理请求是否在排队中
      # @!method processing?
      #   数据处理是否仍在处理中
      #   @return [Boolean] 数据处理是否仍在处理中
      # @!method failed?
      #   数据处理是否已经失败
      #   @return [Boolean] 数据处理是否已经失败
      # @!method callback_failed?
      #   数据处理是否在回调结果 URL 时失败
      #   @return [Boolean] 数据处理是否在回调业务服务器时失败
      def_delegators :get, :done?, *PfopStatus.keys.map { |k| "#{k}?" }

      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      private

      def get_api_url(bucket, api_zone, https)
        https = Config.use_https if https.nil?
        api_zone ||= bucket.zone
        api_zone.api_url(https)
      end
    end
  end
end
