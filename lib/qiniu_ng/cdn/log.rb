# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module CDN
    # 七牛 CDN 日志
    #
    # 存储七牛 CDN 的流量日志或带宽日志
    #
    # @!attribute [r] data
    #   @return [Hash<String, Hash<String, Array<Integer>>>] CDN 数据，由多层嵌套结构组成。
    #     最外层为 Hash 类型，Key 是传入的域名，Value 为第二层 Hash，
    #     它的 Key 是用字符串表示的区域，一般只返回两种区域，'china' 和 'oversea'。
    #     而 Value 则是数组。数组中的数据表示该域名在区域内的每个时间点的数据，这里的时间点与 #times 的返回结果一一对应。
    class Log
      extend Forwardable
      include Enumerable

      attr_reader :data

      # @!visibility private
      def initialize(times, data)
        @times = times
        @parsed_times = nil
        @data = data
        @logs_indices = nil
      end

      # 时间轴上的时间点
      #
      # @return [Array<Time>] 时间轴上的时间点
      def times
        # rubocop:disable Naming/MemoizedInstanceVariableName
        @parsed_times ||= @times.map { |time| Time.parse(time) }
        # rubocop:enable Naming/MemoizedInstanceVariableName
      end

      # 根据时间查询日志数据
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   log = client.cdn_bandwith_log(start_time: 5.days.ago, end_time: Time.now,
      #                                 granularity: :day, domains: [<domain1>, <domain2>])
      #   log.values_at(3.days.ago)
      #   log.values_at(3.days.ago, 'domain1')
      #   log.values_at(3.days.ago, 'domain1', :china)
      #
      # @param [Time] time 要查询的时间点，该时间支持模糊查询，即如果是按天返回的，给出某天任何一个时间点即可查询那一天的日志数据
      # @param [String] domain 要查询的域名
      # @param [Symbol, String] region 要查询的区域，一般只能传入 :china 或 :oversea
      def values_at(time, domain = nil, region = nil)
        log_entry = logs_indices.each_with_index.detect do |h, i|
                      next_time = logs_indices.dig(i + 1, :time)
                      next true if next_time.nil?

                      h[:time] <= time && next_time > time
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

      # @!method each
      #   获取 CDN 日志迭代器
      #   @yield [hash] 传入 Block 对结果进行迭代
      #   @yieldparam hash [Hash] 日志的时间及访问数据
      #   @return [Enumerable] 如果没有给出 Block，则返回迭代器
      def_delegators :logs_indices, :each

      private

      def logs_indices
        @logs_indices ||= times.each_with_index.each_with_object([]) do |(time, index), a|
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
    end
  end
end
