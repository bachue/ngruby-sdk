# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module CDN
    # 七牛 CDN 日志文件集合
    #
    # 该类存储一个 Hash，Key 为日志文件所在域名，而 Value 则为一个数组，
    # 每个数组都是一个 QiniuNg::CDN::LogFile 对象，用于保存一个日志文件。
    #
    # 对本类可以直接调用 {Enumerable}[https://ruby-doc.org/core-2.6.3/Enumerable.html] 内的方法，
    # 用于对该 Hash 的数据进行遍历
    #
    class LogFiles
      extend Forwardable
      include Enumerable

      # @!visibility private
      def initialize(data)
        @data = data.each_with_object({}) do |(domain, d1), h|
          h[domain] = d1.map { |hash| LogFile.new(hash).freeze }.freeze
        end
      end

      # 获取一个域名上对应的全部日志文件
      #
      # @param [String] domain 域名
      # @return [Array<QiniuNg::CDN::LogFile>] 日志文件组
      def [](domain)
        @data[domain]
      end

      def_delegators :@data, :each
    end
  end
end
