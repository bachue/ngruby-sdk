# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/storage/entry'

module QiniuNg
  module Storage
    module Model
      # 列出的资源标识符
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
      # @!attribute [r] created_at
      #   @return [Time] 文件创建时间
      class ListedEntry
        extend Forwardable
        attr_reader :hash, :mime_type, :file_size, :created_at

        # @!visibility private
        attr_reader :end_user, :storage_type, :status

        # @!visibility private
        def initialize(entry, mime_type:, hash:, file_size:, created_at:, end_user:, storage_type:, status:)
          @entry = entry
          @mime_type = mime_type.freeze
          @hash = hash.freeze
          @file_size = file_size.freeze
          @created_at = created_at.freeze
          @end_user = end_user
          @storage_type = storage_type
          @status = status
        end
        def_delegators :@entry, *Storage::Entry.public_instance_methods(false)

        # 存储空间名称
        # @return [String] 存储空间名称
        def bucket_name
          @entry.bucket.name
        end

        # 是否是标准存储
        # @return [String] 是否是标准存储
        def normal_storage?
          @storage_type.nil? || @storage_type == StorageType.normal
        end

        # 是否是低频存储
        # @return [String] 是否是低频存储
        def infrequent_storage?
          @storage_type == StorageType.infrequent
        end

        # 是否未被禁用
        # @return [String] 是否未被禁用
        def enabled?
          @status.nil? || @status.zero?
        end

        # 是否被禁用
        # @return [String] 是否被禁用
        def disabled?
          !enabled?
        end

        # @!visibility private
        def inspect
          "#<#{self.class.name} bucket_name=#{bucket_name.inspect} key=#{@entry.key.inspect}" \
            " @hash=#{@hash.inspect} @mime_type=#{@mime_type.inspect} @file_size=#{@file_size.inspect}" \
            " @created_at=#{@created_at.inspect} @end_user=#{@end_user.inspect}" \
            " @storage_type=#{@storage_type.inspect} @status=#{@status.inspect}>"
        end
      end
    end
  end
end
