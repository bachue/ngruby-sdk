# frozen_string_literal: true

module QiniuNg
  module HTTP
    # 七牛域名管理
    class DomainsManager
      def initialize
        @domains = Concurrent::Map.new
      end

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

      def freeze(domain, frozen_seconds: 10 * 60)
        domain = normalize_domain(domain).freeze
        @domains.put_if_absent(domain, (Time.now + frozen_seconds).freeze)
        nil
      end

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
