# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    module Model
      # 云存储中的资源标识符
      class Entry
        attr_accessor :bucket, :key
        def initialize(bucket:, key: nil)
          @bucket = bucket
          @key = key
        end

        def self.parse(str)
          bucket, key = str.split(':', 2)
          new bucket: bucket, key: key
        end

        def self.decode(str)
          parse(Base64.urlsafe_decode64(str))
        end

        def to_s
          str = @bucket
          str += ':' + @key unless @key.nil? || @key.empty?
          str
        end

        def encode
          Base64.urlsafe_encode64(to_s)
        end
      end
    end
  end
end
