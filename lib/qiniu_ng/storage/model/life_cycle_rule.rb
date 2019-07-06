# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛生命周期规则
      class LifeCycleRule
        attr_reader :name, :prefix, :delete_after_days, :to_line_after_days

        def initialize(rules, name)
          @rules = rules
          @name = name
          @prefix = nil
          @delete_after_days = 0
          @to_line_after_days = 0
        end

        def start_with(prefix)
          @prefix = prefix.to_s
          self
        end

        def delete_after(days:)
          @delete_after_days = days.to_i
          self
        end

        def to_line_after(days:)
          @to_line_after_days = days.to_i
          self
        end

        def always_to_line
          @to_line_after_days = -1
          self
        end

        def always_to_line?
          @to_line_after_days.negative?
        end

        def create!(uc_url: nil, https: nil, **options)
          @rules.send(:create_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end

        def replace!(uc_url: nil, https: nil, **options)
          @rules.send(:replace_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end
        alias update! replace!

        def inspect
          "#<#{self.class.name} @name=#{@name.inspect}> @prefix=#{@prefix.inspect}" \
          " @delete_after_days=#{@delete_after_days.inspect} @to_line_after_days=#{@to_line_after_days.inspect}>"
        end
      end
    end
  end
end
