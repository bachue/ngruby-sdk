# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛生命周期规则
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
      # @!attribute [r] name
      #   @return [String] 存储空间生命周期规则名称
      # @!attribute [r] prefix
      #   @return [String] 存储空间生命周期规则匹配的文件名前缀
      # @!attribute [r] delete_after_days
      #   @return [Integer] 存储空间生命周期规则匹配的文件将在指定天数后被删除，如果为 0 表示不会被删除
      # @!attribute [r] to_line_after_days
      #   @return [Integer] 存储空间生命周期规则匹配的文件将在指定天数后自动转为低频存储，如果为 0 表示不会被转为低频存储，如果为负数表示文件立刻被转为低频存储
      class LifeCycleRule
        attr_reader :name, :prefix, :delete_after_days, :to_line_after_days

        # @!visibility private
        def initialize(rules, name)
          @rules = rules
          @name = name
          @prefix = nil
          @delete_after_days = 0
          @to_line_after_days = 0
        end

        # 设置存储空间生命周期规则匹配的文件名前缀
        # @param [String] prefix 文件名前缀
        # @return [QiniuNg::Storage::Model::LifeCycleRule] 返回上下文
        def start_with(prefix)
          @prefix = prefix.to_s
          self
        end

        # 存储空间生命周期规则匹配的文件将在指定天数后被删除
        # @param [String] days 指定被删除的时间
        # @return [QiniuNg::Storage::Model::LifeCycleRule] 返回上下文
        def delete_after(days:)
          @delete_after_days = days.to_i
          self
        end

        # 存储空间生命周期规则匹配的文件将在指定天数后自动转为低频存储
        # @param [String] days 指定被自动转为低频存储的时间
        # @return [QiniuNg::Storage::Model::LifeCycleRule] 返回上下文
        def to_line_after(days:)
          @to_line_after_days = days.to_i
          self
        end

        # 存储空间生命周期规则匹配的文件将被立刻转换为低频存储
        # @return [QiniuNg::Storage::Model::LifeCycleRule] 返回上下文
        def always_to_line
          @to_line_after_days = -1
          self
        end

        # 存储空间生命周期规则匹配的文件是否将被立刻转换为低频存储
        # @return [Boolean] 是否将被立刻转换为低频存储
        def always_to_line?
          @to_line_after_days.negative?
        end

        # 创建存储空间生命周期规则
        # @param [String] uc_url UC 所在服务器地址，一般无需填写
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [QiniuNg::Storage::LifeCycleRules] 返回规则集合
        def create!(uc_url: nil, https: nil, **options)
          @rules.send(:create_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end

        # 更新存储空间生命周期规则
        # @param [String] uc_url UC 所在服务器地址，一般无需填写
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [QiniuNg::Storage::LifeCycleRules] 返回规则集合
        def replace!(uc_url: nil, https: nil, **options)
          @rules.send(:replace_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end
        alias update! replace!

        # @!visibility private
        def inspect
          "#<#{self.class.name} @name=#{@name.inspect}> @prefix=#{@prefix.inspect}" \
          " @delete_after_days=#{@delete_after_days.inspect} @to_line_after_days=#{@to_line_after_days.inspect}>"
        end
      end
    end
  end
end
