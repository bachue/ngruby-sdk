# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/storage/entry'

module QiniuNg
  module Storage
    module Model
      # 列出的资源标识符
      class ListedEntry
        extend Forwardable
        attr_reader :hash, :mime_type, :file_size, :created_at, :end_user, :storage_type, :status
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

        def bucket_name
          @entry.bucket.name
        end

        def normal_storage?
          @storage_type.nil? || @storage_type == StorageType.normal
        end

        def infrequent_storage?
          @storage_type == StorageType.infrequent
        end

        def enabled?
          @status.nil? || @status.zero?
        end

        def disabled?
          !enabled?
        end

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
