# frozen_string_literal: true

require 'duration'

module Ngqiniu
  module Storage
    module Model
      # 上传策略
      class UploadPolicy
        attr_reader :scope, :bucket, :key
        attr_reader :is_prefixal_scope
        attr_accessor :end_user
        attr_reader :return_url
        attr_reader :return_body
        attr_reader :callback_url
        attr_reader :callback_host
        attr_reader :callback_body
        attr_reader :callback_body_type
        attr_reader :persistent_ops
        attr_reader :persistent_notify_url
        attr_reader :persistent_pipeline
        attr_accessor :save_key
        attr_accessor :fsize_min
        attr_accessor :fsize_limit
        attr_accessor :mime_limit
        attr_accessor :delete_after_days

        def initialize(bucket:, key: nil, key_prefix: nil)
          @bucket = bucket
          @key = key || key_prefix
          @scope = Entry.new(bucket: @bucket, key: @key).encode
          @is_prefixal_scope = !key_prefix.nil?
          @insert_only = nil
          @detect_mime = nil
          @file_type = nil
          @deadline = nil
          @end_user = nil
          @return_url = nil
          @return_body = nil
          @callback_url = nil
          @callback_host = nil
          @callback_body = nil
          @callback_body_type = nil
          @persistent_ops = nil
          @persistent_notify_url = nil
          @persistent_pipeline = nil
          @save_key = nil
          @fsize_min = nil
          @fsize_limit = nil
          @mime_limit = nil
          @delete_after_days = nil
        end

        def lifetime=(lifetime)
          @deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        end

        def lifetime
          Duration.new(seconds: Time.at(@deadline) - Time.now) unless @deadline.nil?
        end

        def deadline=(deadline)
          @deadline = [deadline.to_i, (1 << 32) - 1].min
        end

        def deadline
          Time.at(@deadline) unless @deadline.nil?
        end

        def insert_only?
          !@insert_only.nil?
        end

        def detect_mime?
          !@detect_mime.nil?
        end

        def infrequent?
          @file_type == StorageType.infrequent
        end

        def insert_only!
          @insert_only = true
        end

        def detect_mime!
          @detect_mime = true
        end

        def infrequent!
          @file_type = StorageType.infrequent
        end

        def set_return(url, body: nil)
          @return_url = url
          @return_body = body
        end

        def set_callback(url, host: nil, body: nil, body_type: nil)
          @callback_url = url.is_a?(Array) ? url.join(';') : url
          @callback_host = host
          @callback_body = body
          @callback_body_type = body_type
        end

        def set_persistent_ops(ops, notify_url: nil, pipeline: nil)
          @persistent_ops = ops
          @persistent_notify_url = notify_url
          @persistent_pipeline = pipeline
        end

        def to_h
          to_bool = lambda do |b|
            case b
            when false then 0
            when nil then nil
            else 1
            end
          end
          h = {
            scope: @scope,
            isPrefixalScope: to_bool.call(@is_prefixal_scope),
            insertOnly: to_bool.call(@insert_only),
            detectMime: to_bool.call(@detect_mime),
            endUser: @end_user,
            returnUrl: @return_url,
            returnBody: @return_body,
            callbackUrl: @callback_url,
            callbackHost: @callback_host,
            callbackBody: @callback_body,
            callbackBodyType: @callback_body_type,
            persistentOps: @persistent_ops,
            persistentNotifyUrl: @persistent_notify_url,
            persistentPipeline: @persistent_pipeline,
            saveKey: @save_key,
            fsizeMin: @fsize_min,
            fsizeLimit: @fsize_limit,
            mimeLimit: @mime_limit,
            deadline: @deadline&.to_i,
            deleteAfterDays: @delete_after_days&.to_i,
            file_type: @file_type&.to_i
          }
          h.each_with_object({}) do |(k, v), o|
            o[k] = v unless v.nil?
          end
        end
        alias as_json to_h

        def to_json(*args)
          h = as_json
          require 'json' unless h.respond_to?(:to_json)
          as_json.to_json(*args)
        end
      end
      PutPolicy = UploadPolicy
    end
  end
end
