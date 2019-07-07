# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛生命周期规则集合
    class BucketEventRules
      def initialize(bucket, http_client)
        @bucket = bucket
        @http_client = http_client
      end

      def new(name:)
        Model::BucketEventRule.new(self, name)
      end

      def delete(name:, uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name, name: name }
        @http_client.post('/events/delete', uc_url || get_uc_url(https), params: params, **options)
        self
      end

      def all(uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name }
        body = @http_client.get('/events/get', uc_url || get_uc_url(https), params: params, **options).body
        rules_from_hash(body || [])
      end

      private

      def rules_from_hash(body)
        body.map do |rule_hash|
          Model::BucketEventRule.new(self, rule_hash['name'])
                                .start_with(rule_hash['prefix']).end_with(rule_hash['suffix'])
                                .listen_on(rule_hash['events'])
                                .callback(rule_hash['callback_urls'], host: rule_hash['host'])
        end
      end

      def create_rule(rule, uc_url: nil, https: nil, **options)
        @http_client.post('/events/add', uc_url || get_uc_url(https), params: build_params(rule), **options)
        nil
      end

      def replace_rule(rule, uc_url: nil, https: nil, **options)
        @http_client.post('/events/update', uc_url || get_uc_url(https), params: build_params(rule), **options)
        nil
      end

      def build_params(rule)
        params = {
          bucket: @bucket.name,
          name: rule.name || '', prefix: rule.prefix || '', suffix: rule.suffix || ''
        }
        params[:event] = rule.events unless rule.events.nil? || rule.events.empty?
        unless rule.callback_urls.nil? || rule.callback_urls.empty?
          params[:callbackURL] = rule.callback_urls
          params[:host] = rule.callback_host
        end
        params
      end

      def get_uc_url(https)
        Common::Zone.uc_url(https)
      end
    end
  end
end
