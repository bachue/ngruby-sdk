# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module CDN
    # 七牛 CDN 日志
    class Log
      extend Forwardable
      include Enumerable
      def initialize(times, data)
        @logs = times.each_with_index.each_with_object([]) do |(time, index), a|
          a << {
            time: time,
            data: data.each_with_object({}) do |(domain, values), h|
                    h[domain] = values.each_with_object({}) do |(region, values2), d|
                      d[region] = values2[index]
                    end.freeze
                  end.freeze
          }.freeze
        end.freeze
      end

      def values_at(time, domain = nil, region = nil)
        log_entry = @logs.each_with_index.detect do |h, i|
                      next_time = @logs.dig(i + 1, :time)
                      return true if next_time.nil?

                      Time.parse(h[:time]) <= time && Time.parse(next_time) > time
                    end&.first
        return nil if log_entry.nil?

        opts = [:data]
        if domain
          opts << domain.to_s
          opts << region.to_s if region
        end
        log_entry.dig(*opts)
      end
      alias value_at values_at

      def_delegators :@logs, :each
    end
  end
end
