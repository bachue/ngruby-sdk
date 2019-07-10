# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/processing/pfop_status'

module QiniuNg
  module Processing
    # 七牛文件处理持久化结果
    class PfopResult
      attr_reader :cmd, :code, :description, :error, :key, :keys, :return_old

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

      PfopStatus.to_h.each do |k, v|
        define_method(:"#{k}?") { v == @code }
      end

      def done?
        @code > 1
      end

      def status
        PfopStatus.to_h.detect { |_, v| v == @code }&.first
      end
    end
  end
end
