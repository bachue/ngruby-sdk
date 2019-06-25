# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    # 七牛空间中的文件项
    class Op
      def initialize(entry)
        @entry = entry
      end

      def to_s
        raise NotImplementedError
      end

      def parse(_response)
        nil
      end

      # 获取空间中的文件属性
      class Stat < Op
        def to_s
          "/stat/#{encoded_entry}"
        end

        def parse(response)
          Result.new response
        end

        # 空间中的文件属性
        class Result
          def initialize(hash)
            @hash = {
              file_size: hash['fsize'],
              etag: hash['hash'],
              md5: hash['md5'],
              mime_type: hash['mimeType'],
              put_at: Time.at(hash['putTime'].to_f / 10_000_000),
              storage_type: Model::StorageType.select { |_, v| v.value == hash['type'] }.map { |k, _| k }.first,
              meta: hash['x-qn-meta']
            }
          end

          def [](key)
            @hash[key.to_sym]
          end

          def infrequent_storage?
            @hash[:storage_type] == :infrequent
          end

          def normal_storage?
            @hash[:storage_type] == :normal
          end

          %i[file_size etag md5 mime_type put_at storage_type meta].each do |key|
            define_method(key) { @hash[key] }
          end
          alias content_type mime_type
          alias headers meta
        end
      end

      # 修改空间中的文件状态
      class ChangeStatus < Op
        def initialize(entry, disabled:)
          super(entry)
          @disabled = Utils::Bool.to_int(disabled)
        end

        def to_s
          "/chstatus/#{encoded_entry}/status/#{@disabled}"
        end
      end

      # 修改空间中的文件生命周期
      class SetLifetime < Op
        def initialize(entry, days:)
          super(entry)
          @delete_after_days = days
        end

        def to_s
          "/deleteAfterDays/#{encoded_entry}/#{@delete_after_days}"
        end
      end

      # 修改空间中的文件类型（普通存储或低频存储）
      class ChangeType < Op
        def initialize(entry, type:)
          super(entry)
          @type = type.to_i
        end

        def to_s
          "/chtype/#{encoded_entry}/type/#{@type}"
        end
      end

      # 修改空间中的文件 MIME 类型
      class ChangeMIMEType < Op
        def initialize(entry, mime_type:)
          super(entry)
          @mime_type = mime_type
        end

        def to_s
          "/chgm/#{encoded_entry}/mime/#{Base64.urlsafe_encode64(@mime_type)}"
        end
      end

      # 修改空间中的文件元信息
      class ChangeMeta < Op
        def initialize(entry, meta:)
          super(entry)
          @meta = meta
        end

        def to_s
          str = "/chgm/#{encoded_entry}"
          @meta.each do |key, value|
            str += "/x-qn-meta-#{key}/#{Base64.urlsafe_encode64(value)}"
          end
        end
      end

      # 移动 / 重命名空间中的文件
      class Move < Op
        def initialize(entry, bucket:, key:, force: false)
          super(entry)
          @bucket = bucket
          @key = key
          @force = Utils::Bool.to_bool(force)
        end

        def to_s
          "/move/#{encoded_entry}/#{encode_entry(@bucket, @key)}/force/#{@force}"
        end
      end

      # 复制空间中的文件
      class Copy < Op
        def initialize(entry, bucket:, key:, force: false)
          super(entry)
          @bucket = bucket
          @key = key
          @force = Utils::Bool.to_bool(force)
        end

        def to_s
          "/copy/#{encoded_entry}/#{encode_entry(@bucket, @key)}/force/#{@force}"
        end
      end

      # 删除空间中的文件
      class Delete < Op
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
