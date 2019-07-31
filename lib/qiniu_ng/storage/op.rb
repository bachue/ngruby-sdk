# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    # 存储空间中的文件操作
    class Op
      # @!visibility private
      def initialize(entry)
        @entry = entry
      end

      # @!visibility private
      def to_s
        raise NotImplementedError
      end

      # @!visibility private
      def parse(response)
        BatchOperationResult.new(response)
      end

      # 通用操作属性
      # @!attribute [r] error
      #   @return [String] 错误信息
      class BatchOperationResult
        attr_reader :error
        # @!visibility private
        def initialize(hash)
          @error = hash&.dig('error')
        end
      end

      # 获取空间中的文件属性
      class Stat < Op
        # @!visibility private
        def to_s
          "/stat/#{encoded_entry}"
        end

        # @!visibility private
        def parse(response)
          Result.new response
        end

        # 空间中的文件属性
        # @!attribute [r] file_size
        #   @return [Integer] 文件大小，单位为字节
        # @!attribute [r] etag
        #   @return [String] 文件 Etag
        # @!attribute [r] mime_type
        #   @return [String] 文件 MIME 类型
        # @!attribute [r] put_at
        #   @return [Time] 文件创建时间
        # @!attribute [r] meta
        #   @return [Hash] 文件的 HTTP Header 信息
        # @!attribute [r] error
        #   @return [String] 错误信息
        class Result
          # @!visibility private
          def initialize(hash)
            @hash = {
              error: hash['error'],
              file_size: hash['fsize'],
              etag: hash['hash'],
              md5: hash['md5'],
              mime_type: hash['mimeType'],
              put_at: Time.at(hash['putTime'].to_f / 10_000_000),
              storage_type: Model::StorageType.select { |_, v| v.value == hash['type'] }.map { |k, _| k }.first,
              meta: hash['x-qn-meta']
            }
          end

          # @!visibility private
          def [](key)
            @hash[key.to_sym]
          end

          # 文件是否使用低频存储
          #
          # @return [Boolean] 文件是否使用低频存储
          def infrequent_storage?
            @hash[:storage_type] == :infrequent
          end

          # 文件是否使用标准存储
          #
          # @return [Boolean] 文件是否使用标准存储
          def normal_storage?
            @hash[:storage_type] == :normal
          end

          %i[file_size etag md5 mime_type put_at storage_type meta error].each do |key|
            define_method(key) { @hash[key] }
          end
          alias content_type mime_type
          alias headers meta
        end
      end

      # @!visibility private
      class ChangeStatus < Op
        # @!visibility private
        def initialize(entry, disabled:)
          super(entry)
          @disabled = Utils::Bool.to_int(disabled)
        end

        # @!visibility private
        def to_s
          "/chstatus/#{encoded_entry}/status/#{@disabled}"
        end
      end

      # @!visibility private
      class SetLifetime < Op
        # @!visibility private
        def initialize(entry, days:)
          super(entry)
          @delete_after_days = days
        end

        # @!visibility private
        def to_s
          "/deleteAfterDays/#{encoded_entry}/#{@delete_after_days}"
        end
      end

      # @!visibility private
      class ChangeType < Op
        # @!visibility private
        def initialize(entry, type:)
          super(entry)
          @type = type.to_i
        end

        # @!visibility private
        def to_s
          "/chtype/#{encoded_entry}/type/#{@type}"
        end
      end

      # @!visibility private
      class ChangeMIMEType < Op
        # @!visibility private
        def initialize(entry, mime_type:)
          super(entry)
          @mime_type = mime_type
        end

        # @!visibility private
        def to_s
          "/chgm/#{encoded_entry}/mime/#{Base64.urlsafe_encode64(@mime_type)}"
        end
      end

      # @!visibility private
      class ChangeMeta < Op
        # @!visibility private
        def initialize(entry, meta:)
          super(entry)
          @meta = meta
        end

        # @!visibility private
        def to_s
          str = "/chgm/#{encoded_entry}"
          @meta.each do |key, value|
            str += "/x-qn-meta-#{key}/#{Base64.urlsafe_encode64(value)}"
          end
        end
      end

      # @!visibility private
      class Move < Op
        # @!visibility private
        def initialize(entry, bucket:, key:, force: false)
          super(entry)
          @bucket = bucket
          @key = key
          @force = Utils::Bool.to_bool(force)
        end

        # @!visibility private
        def to_s
          "/move/#{encoded_entry}/#{encode_entry(@bucket, @key)}/force/#{@force}"
        end
      end

      # @!visibility private
      class Copy < Op
        # @!visibility private
        def initialize(entry, bucket:, key:, force: false)
          super(entry)
          @bucket = bucket
          @key = key
          @force = Utils::Bool.to_bool(force)
        end

        # @!visibility private
        def to_s
          "/copy/#{encoded_entry}/#{encode_entry(@bucket, @key)}/force/#{@force}"
        end
      end

      # @!visibility private
      class Delete < Op
        # @!visibility private
        def to_s
          "/delete/#{encoded_entry}"
        end
      end

      private

      def encoded_entry
        @entry.encode
      end

      def encode_entry(bucket, key)
        Base64.urlsafe_encode64("#{bucket}:#{key}")
      end
    end
  end
end
