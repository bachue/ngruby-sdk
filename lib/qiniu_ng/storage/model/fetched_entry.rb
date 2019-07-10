# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/storage/entry'

module QiniuNg
  module Storage
    module Model
      # 抓取的资源标识符
      #
      # 本类是 QiniuNg::Storage::Entry 的子类，父类中所有方法都可以通过本类直接调用
      #
      # @!attribute [r] key
      #   @return [String] 文件名
      # @!attribute [r] hash
      #   @return [String] 文件的 Etag
      # @!attribute [r] mime_type
      #   @return [String] 文件的 MIME 类型
      # @!attribute [r] file_size
      #   @return [Integer] 文件大小，单位为字节
      class FetchedEntry
        extend Forwardable
        attr_reader :hash, :mime_type, :file_size

        # @!visibility private
        def initialize(entry, mime_type:, hash:, file_size:)
          @entry = entry
          @mime_type = mime_type.freeze
          @hash = hash.freeze
          @file_size = file_size.freeze
        end
        def_delegators :@entry, *Storage::Entry.public_instance_methods(false)

        # 存储空间名称
        # @return [String] 存储空间名称
        def bucket_name
          @entry.bucket.name
        end

        # @!visibility private
        def inspect
          "#<#{self.class.name} bucket_name=#{bucket_name.inspect} key=#{@entry.key.inspect}" \
            " @hash=#{@hash.inspect} @mime_type=#{@mime_type.inspect} @file_size=#{@file_size.inspect}>"
        end
      end
    end
  end
end
