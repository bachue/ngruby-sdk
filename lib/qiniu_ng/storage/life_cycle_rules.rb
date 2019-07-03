# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛生命周期规则集合
    class LifeCycleRules
      def initialize(bucket, http_client, auth)
        @bucket = bucket
        @http_client = http_client
        @auth = auth
      end

      def new(name:)
        Model::LifeCycleRule.new(self, name)
      end

      def delete(name:, uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name, name: name }
        @http_client.post("#{uc_url || get_uc_url(https)}/rules/delete", params: params, **options)
        self
      end

      def all(uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name }
        body = @http_client.get("#{uc_url || get_uc_url(https)}/rules/get", params: params, **options).body
        rules_from_hash(body || [])
      end

      private

      def rules_from_hash(body)
        body.map do |rule_hash|
          Model::LifeCycleRule.new(self, rule_hash['name']).start_with(rule_hash['prefix'])
                              .delete_after(days: rule_hash['delete_after_days'])
                              .to_line_after(days: rule_hash['to_line_after_days'])
        end
      end

      def create_rule(rule, uc_url: nil, https: nil, **options)
        params = build_params(rule)
        @http_client.post("#{uc_url || get_uc_url(https)}/rules/add", params: params, **options)
        nil
      end

      def replace_rule(rule, uc_url: nil, https: nil, **options)
        params = build_params(rule)
        @http_client.post("#{uc_url || get_uc_url(https)}/rules/update", params: params, **options)
        nil
      end

      def build_params(rule)
        {
          bucket: @bucket.name,
          name: rule.name || '', prefix: rule.prefix || '',
          delete_after_days: rule.delete_after_days || 0,
          to_line_after_days: rule.to_line_after_days || 0
        }
      end

      def get_uc_url(https)
        Utils::Bool.to_bool(https) ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
      end
    end
  end
end
