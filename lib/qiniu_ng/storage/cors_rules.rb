# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛 CORS 规则集合
    class CORSRules
      include Enumerable

      # @!visibility private
      def initialize(bucket, http_client)
        @bucket = bucket
        @http_client = http_client
        @rules = []
      end

      # 创建存储空间跨域规则
      #
      # @example 创建存储空间跨域规则
      #   cors_rules = bucket.cors_rules
      #   new_rule1 = cors_rules.new(%w[http://www.t1.com http://www.t2.com], %w[GET DELETE]).cache_max_age(days: 365)
      #   new_rule2 = cors_rules.new(%w[http://www.t3.com http://www.t4.com], %w[POST PUT]).cache_max_age(days: 365)
      #   cors_rules.set([new_rule1, new_rule2])
      #
      # @param [Array<String>, String] allowed_origins 允许的域名
      #   <br>支持通配符`*`；`*`表示全部匹配；
      #   <br>只有第一个`*`生效；需要设置传输协议；大小写敏感。例如：
      #   <br>规则："http://*.abc.*.com" 请求："http://test.abc.test.com"   结果：不通过；
      #   <br>规则："http://abc.com"     请求："https://abc.com" / "abc.com"  结果：不通过；
      #   <br>规则："abc.com"            请求："http://abc.com"             结果：不通过；
      # @param [Array<String>, String] allowed_methods 允许的方法
      #   <br>支持通配符`*`，但只能是单独的`*`，表示允许全部 HTTP Header，其他`*`不生效；
      #   <br>空则不允许任何 HTTP Header；大小写不敏感
      # @return [QiniuNg::Storage::Model::CORSRule] 返回跨域规则实例
      def new(allowed_origins, allowed_methods = nil)
        Model::CORSRule.new(self, allowed_origins, allowed_methods)
      end

      # 获取全部存储空间跨域规则
      #
      # @example
      #   bucket.cors_rules.all
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<QiniuNg::Storage::Model::CORSRule>] 返回规则集合
      def all(uc_url: nil, https: nil, **options)
        get_cors_rules(uc_url: uc_url, https: https, **options)
      end

      # 更新存储空间跨域规则集合
      #
      # @example 更新存储空间跨域规则
      #   cors_rules = bucket.cors_rules
      #   new_rule1 = cors_rules.new(%w[http://www.t1.com http://www.t2.com], %w[GET DELETE]).cache_max_age(days: 365)
      #   new_rule2 = cors_rules.new(%w[http://www.t3.com http://www.t4.com], %w[POST PUT]).cache_max_age(days: 365)
      #   cors_rules.set([new_rule1, new_rule2])
      #
      # @param [Array<QiniuNg::Storage::Model::CORSRule>] rules 设置跨域规则集合
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<QiniuNg::Storage::Model::CORSRule>] 返回规则集合
      def set(rules, uc_url: nil, https: nil, **options)
        @http_client.post("/corsRules/set/#{@bucket.name}", uc_url || get_uc_url(https),
                          body: Config.default_json_marshaler.call(rules.map(&:as_json)),
                          headers: { content_type: 'application/json' },
                          **options)
        get_cors_rules(uc_url: uc_url, https: https, **options)
      end

      # 清空存储空间跨域规则集合
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<QiniuNg::Storage::Model::CORSRule>] 返回规则集合
      def clear(uc_url: nil, https: nil, **options)
        set([], uc_url: uc_url, https: https, **options)
      end

      # 获取存储空间跨域规则迭代器
      #
      # @example 获取迭代器
      #   bucket.cors_rules.each
      #
      # @example 直接使用迭代器遍历所有跨域规则
      #   bucket.cors_rules.find_all { |rule| rule.allowed_methods.include?('GET') }
      #
      # @return [Enumerator] 返回迭代器
      def each
        return all.each unless block_given?

        all.each do |rule|
          yield rule
        end
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
