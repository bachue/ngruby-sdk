# frozen_string_literal: true

module QiniuNg
  module Processing
    # 七牛文件处理管理
    class OperationManager
      def initialize(http_client_v1)
        @http_client_v1 = http_client_v1
      end

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
