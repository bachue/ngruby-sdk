# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module CDN
    # 七牛 CDN 日志文件集合
    class LogFiles
      extend Forwardable
      include Enumerable

      def initialize(data)
        @data = data.each_with_object({}) do |(domain, d1), h|
          h[domain] = d1.map { |hash| LogFile.new(hash).freeze }.freeze
        end
      end

      def [](domain)
        @data[domain]
      end

      def_delegators :@data, :each
    end
  end
end
