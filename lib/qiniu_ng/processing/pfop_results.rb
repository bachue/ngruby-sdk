# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/processing/pfop_status'

module QiniuNg
  module Processing
    # 七牛文件处理持久化结果集合
    #
    # 该类型本身也是一个{迭代器}[https://ruby-doc.org/core-2.6/Enumerable.html]，
    # 可以调用迭代器方法遍历持久化处理结果
    #
    # @see https://developer.qiniu.com/dora/manual/1294/persistent-processing-status-query-prefop
    #
    # @!attribute [r] description
    #   @return [String] 描述信息
    # @!attribute [r] bucket
    #   @return [String] 存储空间名称
    # @!attribute [r] key
    #   @return [String] 进行处理的文件名
    class PfopResults
      extend Forwardable
      include Enumerable

      attr_reader :description, :bucket, :key

      # @!visibility private
      def initialize(hash)
        @code = hash['code']
        @description = hash['description']
        @bucket = hash['inputBucket']
        @key = hash['inputKey']
        @results = hash['items'].map { |item_hash| PfopResult.new(item_hash) }.freeze
      end

      # @!method ok?
      #   数据处理是否已经成功
      #   @return [Boolean] 数据处理是否已经成功
      # @!method pending?
      #   数据处理请求是否在排队中
      #   @return [Boolean] 数据处理请求是否在排队中
      # @!method processing?
      #   数据处理是否仍在处理中
      #   @return [Boolean] 数据处理是否仍在处理中
      # @!method failed?
      #   数据处理是否已经失败
      #   @return [Boolean] 数据处理是否已经失败
      # @!method callback_failed?
      #   数据处理是否在回调结果 URL 时失败
      #   @return [Boolean] 数据处理是否在回调业务服务器时失败
      PfopStatus.to_h.each do |k, v|
        define_method(:"#{k}?") { v == @code }
      end

      # 数据处理是否已经结束
      # @return [Boolean] 数据处理是否已经结束
      def done?
        ![1, 2].include?(@code)
      end

      # 数据处理结果
      # @return [Symbol] 返回数据处理结果，
      #   :ok 表示成功，
      #   :pending 表示请求在排队中，
      #   :processing 表示数据在处理中，
      #   :failed 表示数据处理失败，
      #   :callback_failed 表示数据处理结束，但回调业务服务器失败
      def status
        PfopStatus.to_h.detect { |_, v| v == @code }.first
      end

      def_delegators :@results, :each, :size
    end
  end
end
