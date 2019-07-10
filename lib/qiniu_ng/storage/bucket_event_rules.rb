# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛事件规则集合
    class BucketEventRules
      include Enumerable

      # @!visibility private
      def initialize(bucket, http_client)
        @bucket = bucket
        @http_client = http_client
      end

      # 新建/更新存储空间事件规则
      #
      # @example 创建存储空间事件规则
      #   bucket.bucket_event_rules.new(name: 'test_rule1')
      #                            .listen_on(event_types1)
      #                            .callback('http://www.test1.com')
      #                            .create!
      # @example 更新存储空间事件规则
      #   bucket.bucket_event_rules.new(name: 'test_rule1')
      #                            .listen_on(event_types1)
      #                            .callback('http://www.test1.com')
      #                            .replace!
      #
      # @param [String] name 事件规则名称，要求在存储空间内唯一，长度小于 50，不能为空，只能由字母、数字、下划线组成
      # @return [QiniuNg::Storage::Model::BucketEventRule] 返回事件规则实例
      def new(name:)
        Model::BucketEventRule.new(self, name)
      end

      # 删除存储空间事件规则
      #
      # @example
      #   bucket.bucket_event_rules.delete(name: 'test_rule1')
      #
      # @param [String] name 要删除的事件规则名称
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::BucketEventRules] 返回上下文
      def delete(name:, uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name, name: name }
        @http_client.post('/events/delete', uc_url || get_uc_url(https), params: params, **options)
        self
      end

      # 获取全部存储空间事件规则
      #
      # @example
      #   bucket.bucket_event_rules.all
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<QiniuNg::Storage::Model::BucketEventRule>] 返回规则集合
      def all(uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name }
        body = @http_client.get('/events/get', uc_url || get_uc_url(https), params: params, **options).body
        rules_from_hash(body || [])
      end

      # 获取存储空间事件规则迭代器
      #
      # @example 获取迭代器
      #   bucket.bucket_event_rules.each
      #
      # @example 直接使用迭代器遍历所有事件规则
      #   bucket.bucket_event_rules.find { |rule| rule.name == 'name' }
      # @return [Enumerator] 返回迭代器
      def each
        return all.each unless block_given?

        all.each do |rule|
          yield rule
        end
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
