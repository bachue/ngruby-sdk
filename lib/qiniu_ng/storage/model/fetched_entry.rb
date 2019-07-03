# frozen_string_literal: true

require 'forwardable'
require 'qiniu_ng/storage/entry'

module QiniuNg
  module Storage
    module Model
      # 抓取的资源标识符
      class FetchedEntry
        extend Forwardable
        attr_reader :hash, :mime_type, :file_size
        def initialize(entry, mime_type:, hash:, file_size:)
          @entry = entry
          @mime_type = mime_type.freeze
          @hash = hash.freeze
          @file_size = file_size.freeze
        end
        def_delegators :@entry, *Storage::Entry.public_instance_methods(false)

        def bucket_name
          @entry.bucket.name
        end

        def inspect
          "#<#{self.class.name} bucket_name=#{bucket_name.inspect} key=#{@entry.key.inspect}" \
            " @hash=#{@hash.inspect} @mime_type=#{@mime_type.inspect} @file_size=#{@file_size.inspect}>"
        end
      end
    end
  end
end
