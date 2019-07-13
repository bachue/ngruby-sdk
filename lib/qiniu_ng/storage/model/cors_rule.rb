# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛跨域规则
      #
      # @example 创建存储空间跨域规则
      #   cors_rules = bucket.cors_rules
      #   new_rule1 = cors_rules.new(%w[http://www.t1.com http://www.t2.com], %w[GET DELETE]).cache_max_age(days: 365)
      #   new_rule2 = cors_rules.new(%w[http://www.t3.com http://www.t4.com], %w[POST PUT]).cache_max_age(days: 365)
      #   cors_rules.set([new_rule1, new_rule2])
      #
      # @!attribute [r] allowed_origins
      #   @return [Array<String>] 允许的域名
      # @!attribute [r] allowed_methods
      #   @return [Array<String>] 允许的方法
      # @!attribute [r] allowed_headers
      #   @return [Array<String>] 允许的 HTTP Header
      # @!attribute [r] exposed_headers
      #   @return [Array<String>] 暴露的 HTTP Header
      # @!attribute [r] max_age
      #   @return [Integer] 结果可以缓存的时间
      class CORSRule
        attr_reader :allowed_origins, :allowed_methods, :allowed_headers, :exposed_headers, :max_age

        # @!visibility private
        def initialize(rules, allowed_origins, allowed_methods)
          allowed_origins = [allowed_origins].compact unless allowed_origins.is_a?(Array)
          allowed_methods = [allowed_methods].compact unless allowed_methods.is_a?(Array)
          @rules = rules
          @allowed_origins = allowed_origins
          @allowed_methods = allowed_methods
          @allowed_headers = []
          @exposed_headers = []
          @max_age = nil
        end

        # 添加允许的 HTTP Header
        #
        # @param [Array<String>, String] allowed_headers 允许的 HTTP Header
        #   <br>支持通配符`*`，但只能是单独的`*`，表示允许全部 HTTP Header，其他`*`不生效；
        #   <br>空则不允许任何 HTTP Header；大小写不敏感；
        def add_allowed_headers(allowed_headers)
          return self if allowed_headers.nil?

          allowed_headers = [allowed_headers].compact unless allowed_headers.is_a?(Array)
          @allowed_headers += allowed_headers
          self
        end

        # 添加暴露的 HTTP Header
        #
        # @param [Array<String>, String] exposed_headers 暴露的 HTTP Header
        #   <br>不支持通配符；X-Log, X-Reqid 是默认会暴露的两个 HTTP Header
        #   <br>其他的 HTTP Header 如果没有设置，则不会暴露；大小写不敏感；
        def add_exposed_headers(exposed_headers)
          return self if exposed_headers.nil?

          exposed_headers = [exposed_headers].compact unless exposed_headers.is_a?(Array)
          @exposed_headers += exposed_headers
          self
        end

        # 设置结果可以缓存的时间
        #
        # @example
        #   new_rule1 = cors_rules.new(%w[http://www.t1.com http://www.t2.com], %w[GET DELETE]).cache_max_age(days: 365)
        #
        # @param [Integer, Hash, QiniuNg::Duration] max_age 时间长度，可以用 Hash 表示，
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        def cache_max_age(max_age)
          max_age = Utils::Duration.new(max_age) if max_age.is_a?(Hash)
          @max_age = max_age&.to_i
          self
        end

        # @!visibility private
        def as_json
          h = { allowed_origin: @allowed_origins, allowed_method: @allowed_methods }
          h[:max_age] = @max_age unless @max_age.nil?
          h[:allowed_header] = @allowed_headers unless @allowed_headers.nil? || @allowed_headers.empty?
          h[:exposed_header] = @exposed_headers unless @exposed_headers.nil? || @exposed_headers.empty?
          h
        end

        # @!visibility private
        def inspect
          "#<#{self.class.name} @allowed_origins=#{@allowed_origins.inspect}" \
          " @allowed_methods=#{@allowed_methods.inspect} @allowed_headers=#{@allowed_headers.inspect}" \
          " @exposed_headers=#{@exposed_headers} @max_age=#{@max_age.inspect}>"
        end
      end
    end
  end
end
