# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/processing/pfop_status'

module QiniuNg
  module Processing
    # 七牛文件处理持久化结果
    #
    # @!attribute [r] cmd
    #   @return [String] fop 数据处理参数
    # @!attribute [r] description
    #   @return [String] 描述信息
    # @!attribute [r] error
    #   @return [String, nil] 如果处理失败，将返回错误详细信息
    # @!attribute [r] key
    #   @return [String] 处理结果的文件名
    # @!attribute [r] keys
    #   @return [Array<String>] 处理结果的文件名集合
    # @!attribute [r] return_old
    #   @return [Boolean] 是否返回旧数据，
    #     如果用户指定了处理结果文件名，同时没有传入 force 参数。而该文件已经存在，则系统不再重复处理，该属性将返回 true
    class PfopResult
      attr_reader :cmd, :description, :error, :key, :keys, :return_old

      def initialize(hash)
        @cmd = hash['cmd']
        @code = hash['code']
        @description = hash['description']
        @error = hash['error']
        @keys = hash['keys'] || [hash['key']].compact
        @key = hash['key']
        @return_old = !hash['returnOld'].zero?
      end

      alias return_old? return_old

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
        @code > 1
      end

      # 数据处理结果
      # @return [Symbol] 返回数据处理结果，
      #   :ok 表示成功，
      #   :pending 表示请求在排队中，
      #   :processing 表示数据在处理中，
      #   :failed 表示数据处理失败，
      #   :callback_failed 表示数据处理结束，但回调业务服务器失败
      def status
        PfopStatus.to_h.detect { |_, v| v == @code }&.first
      end
    end
  end
end
