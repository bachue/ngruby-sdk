# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/processing/pfop_status'

module QiniuNg
  module Processing
    # 七牛文件处理持久化结果
    class PfopResults
      extend Forwardable
      include Enumerable

      attr_reader :persistent_id, :code, :description, :bucket, :key

      def initialize(hash)
        @persistent_id = hash['id']
        @code = hash['code']
        @description = hash['description']
        @bucket = hash['inputBucket']
        @key = hash['inputKey']
        @results = hash['items'].map { |item_hash| PfopResult.new(item_hash) }
      end

      PfopStatus.to_h.each do |k, v|
        define_method(:"#{k}?") { v == @code }
      end

      def done?
        @code > 1
      end

      def status
        PfopStatus.to_h.detect { |_, v| v == @code }.first
      end

      def_delegators :@results, :each
    end
  end
end
