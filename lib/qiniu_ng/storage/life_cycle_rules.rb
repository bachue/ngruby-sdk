# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛生命周期规则集合
    class LifeCycleRules
      include Enumerable

      # @!visibility private
      def initialize(bucket, http_client)
        @bucket = bucket
        @http_client = http_client
      end

      # 新建/更新存储空间生命周期规则
      #
      # @example 创建存储空间生命周期规则
      #   bucket.life_cycle_rules.new(name: 'test_rule1')
      #                          .start_with('temp')
      #                          .delete_after(days: 3)
      #                          .always_to_line
      #                          .create!
      # @example 更新存储空间生命周期规则
      #   bucket.life_cycle_rules.new(name: 'test_rule1')
      #                          .start_with('temp')
      #                          .delete_after(days: 3)
      #                          .always_to_line
      #                          .replace!
      #
      # @param [String] name 生命周期规则名称，要求在存储空间内唯一，长度小于 50，不能为空，只能由字母、数字、下划线组成
      # @return [QiniuNg::Storage::Model::LifeCycleRule] 返回生命周期规则实例
      def new(name:)
        Model::LifeCycleRule.new(self, name)
      end

      # 删除存储空间生命周期规则
      #
      # @example
      #   bucket.life_cycle_rules.delete(name: 'test_rule1')
      #
      # @param [String] name 要删除的生命周期规则名称
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::LifeCycleRules] 返回上下文
      def delete(name:, uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name, name: name }
        @http_client.post('/rules/delete', uc_url || get_uc_url(https), params: params, **options)
        self
      end

      # 获取全部存储空间生命周期规则
      #
      # @example
      #   bucket.life_cycle_rules.all
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<QiniuNg::Storage::Model::LifeCycleRule>] 返回规则集合
      def all(uc_url: nil, https: nil, **options)
        params = { bucket: @bucket.name }
        body = @http_client.get('/rules/get', uc_url || get_uc_url(https), params: params, **options).body
        rules_from_hash(body || [])
      end

      # 获取存储空间生命周期规则迭代器
      #
      # @example 获取迭代器
      #   bucket.life_cycle_rules.each
      #
      # @example 直接使用迭代器遍历所有生命周期规则
      #   bucket.life_cycle_rules.find { |rule| rule.name == 'name' }
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
          Model::LifeCycleRule.new(self, rule_hash['name']).start_with(rule_hash['prefix'])
                              .delete_after(days: rule_hash['delete_after_days'])
                              .to_line_after(days: rule_hash['to_line_after_days'])
        end
      end

      def create_rule(rule, uc_url: nil, https: nil, **options)
        params = build_params(rule)
        @http_client.post('/rules/add', uc_url || get_uc_url(https), params: params, **options)
        nil
      end

      def replace_rule(rule, uc_url: nil, https: nil, **options)
        params = build_params(rule)
        @http_client.post('/rules/update', uc_url || get_uc_url(https), params: params, **options)
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
        Common::Zone.uc_url(https)
      end
    end
  end
end
