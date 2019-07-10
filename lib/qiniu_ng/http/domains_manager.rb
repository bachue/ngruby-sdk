# frozen_string_literal: true

module QiniuNg
  module HTTP
    # 七牛域名管理器
    class DomainsManager
      # @!visibility private
      def initialize
        @domains = Concurrent::Map.new
      end

      # 判定指定域名是否可用
      #
      # @param [String] domain 域名
      # @return [Boolean] 该域名是否冻结
      def frozen?(domain)
        domain = normalize_domain(domain).freeze
        unfreeze_time = @domains.fetch(domain, nil)
        return false if unfreeze_time.nil?

        if unfreeze_time < Time.now
          @domains.delete_pair(domain, unfreeze_time)
          return false
        end
        true
      end

      # 标记指定域名为不可用
      #
      # @param [String] domain 被标记为不可用的域名
      # @param [Integer] frozen_seconds 冻结时间长度，单位为秒
      def freeze(domain, frozen_seconds: 10 * 60)
        domain = normalize_domain(domain).freeze
        @domains.put_if_absent(domain, (Time.now + frozen_seconds).freeze)
        nil
      end

      # 标记所有域名为可用
      def unfreeze_all!
        @domains.keys.each { |key| @domains.delete(key) }
      end

      private

      def normalize_domain(domain)
        domain.sub(%r{^(\w+://)?([^/]+)(/.*)?$}, '\2')
      end
    end
  end
end
