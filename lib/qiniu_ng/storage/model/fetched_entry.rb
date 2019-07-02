# frozen_string_literal: true

require 'base64'
require 'forwardable'
require 'qiniu_ng/storage/entry'

module QiniuNg
  module Storage
    module Model
      # 抓取的资源标识符
      class FetchedEntry
        extend Forwardable
        attr_reader :hash, :key, :mime_type, :file_size
        def initialize(entry, key:, mime_type:, hash:, file_size:)
          @entry = entry
          @key = key.freeze
          @mime_type = mime_type.freeze
          @hash = hash.freeze
          @file_size = file_size.freeze
        end
        def_delegators :@entry, *Storage::Entry.public_instance_methods(false)
      end
    end
  end
end
