# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛 CORS 规则集合
    class CORSRules
      def initialize(bucket, http_client)
        @bucket = bucket
        @http_client = http_client
        @rules = []
      end

      def new(allowed_origins, allowed_methods)
        Model::CORSRule.new(self, allowed_origins, allowed_methods)
      end

      def all(uc_url: nil, https: nil, **options)
        get_cors_rules(uc_url: uc_url, https: https, **options)
      end

      def set(rules, uc_url: nil, https: nil, **options)
        @http_client.post("/corsRules/set/#{@bucket.name}", uc_url || get_uc_url(https),
                          body: Config.default_json_marshaler.call(rules.map(&:as_json)),
                          headers: { content_type: 'application/json' },
                          **options)
        get_cors_rules(uc_url: uc_url, https: https, **options)
      end

      def clear(uc_url: nil, https: nil, **options)
        set([], uc_url: uc_url, https: https, **options)
      end

      private

      def get_cors_rules(uc_url: nil, https: nil, **options)
        resp_body = @http_client.get("/corsRules/get/#{@bucket.name}", uc_url || get_uc_url(https), **options).body
        @rules = rules_from_hash(resp_body || [])
      end

      def rules_from_hash(body)
        body.map do |rule_hash|
          Model::CORSRule.new(self, rule_hash['allowed_origin'], rule_hash['allowed_method'])
                         .add_allowed_headers(rule_hash['allowed_header'])
                         .add_exposed_headers(rule_hash['exposed_header'])
                         .cache_max_age(rule_hash['max_age'])
        end
      end

      def get_uc_url(https)
        Common::Zone.uc_url(https)
      end
    end
  end
end
