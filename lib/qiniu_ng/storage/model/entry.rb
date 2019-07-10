# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    module Model
      # 云存储中的资源标识符
      # @!attribute [r] bucket
      #   @return [String] 存储空间名称
      # @!attribute [r] key
      #   @return [String] 文件名
      class Entry
        attr_accessor :bucket, :key

        # @!visibility private
        def initialize(bucket:, key: nil)
          @bucket = bucket.freeze
          @key = key.freeze
        end

        # 解析资源标识符
        # @param [String] str 资源标识符字符串
        # @return [QiniuNg::Storage::Model::Entry] 返回资源标识符实例
        def self.parse(str)
          bucket, key = str.split(':', 2)
          new bucket: bucket, key: key
        end

        # 解析经过 Base64 处理过的资源标识符
        # @param [String] str 经过 Base64 处理过的资源标识符字符串
        # @return [QiniuNg::Storage::Model::Entry] 返回资源标识符实例
        def self.decode(str)
          parse(Base64.urlsafe_decode64(str))
        end

        # 生成资源标识符字符串
        # @return [String] 返回资源标识符字符串
        def to_s
          str = @bucket
          str += ':' + @key unless @key.nil? || @key.empty?
          str
        end

        # 生成经过 Base64 处理过的资源标识符字符串
        # @return [String] 返回经过 Base64 处理过的资源标识符字符串
        def encode
          Base64.urlsafe_encode64(to_s)
        end
      end
    end
  end
end
