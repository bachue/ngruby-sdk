# frozen_string_literal: true

module QiniuNg
  module Processing
    # 七牛文件处理管理
    #
    # 该类所有方法都已被委托给 QiniuNg::Client 直接调用
    class Manager
      # @!visibility private
      def initialize(http_client_v1)
        @http_client_v1 = http_client_v1
      end

      # 发送请求对空间中的文件进行持久化处理
      #
      # @param [QiniuNg::Storage::Entry] entry 需要被持久化处理的空间文件
      # @param [Array<String>, String] fop 数据处理参数。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] pipeline 数据处理队列。
      #   {参考文档}[https://developer.qiniu.com/dora/kb/3853/how-to-create-audio-and-video-processing-private-queues]
      # @param [String] notify_url 处理结果通知接收 URL。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1291/persistent-data-processing-pfop#pfop-notification]
      # @param [Boolean] force 强制执行数据处理。
      #   当服务端发现 fop 指定的数据处理结果已经存在，那就认为已经处理成功，避免重复处理浪费资源。
      #   如果传入 true，则可强制执行数据处理并覆盖原结果
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [PersistentID] 返回持久化 ID
      def pfop(entry, fop, pipeline:, notify_url: nil, force: nil, api_zone: nil, https: nil, **options)
        fop = [fop] unless fop.is_a?(Array)
        req_body = Faraday::Utils::ParamsHash.new
        req_body.update bucket: entry.bucket.name, key: entry.key, fops: fop.join(';')
        req_body[:notifyURL] = notify_url
        req_body[:force] = Utils::Bool.to_int(force) unless force.nil?
        req_body[:pipeline] = pipeline if pipeline
        resp_body = @http_client_v1.post('/pfop', get_api_url(entry, api_zone, https),
                                         body: req_body.to_query, **options).body
        PersistentID.new(resp_body['persistentId'], @http_client_v1, entry)
      end

      private

      def get_api_url(entry, api_zone, https)
        https = Config.use_https if https.nil?
        api_zone ||= entry.bucket.zone
        api_zone.api_url(https)
      end
    end
  end
end
