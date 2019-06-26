# frozen_string_literal: true

require 'duration'

module QiniuNg
  module Storage
    module Model
      # 七牛上传策略
      class UploadPolicy
        module Errors
          class InvalidUploadToken < ArgumentError
          end
        end

        attr_reader :scope, :bucket, :key
        attr_reader :return_url, :return_body
        attr_reader :callback_url, :callback_host, :callback_body, :callback_body_type
        attr_reader :persistent_ops, :persistent_notify_url, :persistent_pipeline
        attr_accessor :end_user
        attr_reader :min_file_size, :max_file_size
        attr_reader :save_key, :force_save_key

        def initialize(bucket:, key: nil, key_prefix: nil)
          @bucket = bucket
          @key = key || key_prefix
          @scope = Entry.new(bucket: @bucket, key: @key).to_s
          @is_prefixal_scope = key_prefix.nil? ? nil : true
          if key.nil?
            @save_key = nil
            @force_save_key = nil
          else
            @save_key = key
            @force_save_key = true
          end
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
          @min_file_size = nil
          @max_file_size = nil
          @mime_limit = nil
          @delete_after_days = nil
        end

        def token_lifetime=(lifetime)
          @deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        end

        # rubocop:disable Naming/AccessorMethodName
        def set_token_lifetime(*args)
          self.token_lifetime = Duration.new(*args)
          self
        end
        # rubocop:enable Naming/AccessorMethodName

        def token_lifetime
          Duration.new(seconds: Time.at(@deadline) - Time.now) unless @deadline.nil?
        end

        def token_deadline=(deadline)
          @deadline = [deadline.to_i, (1 << 32) - 1].min
        end

        def token_deadline
          Time.at(@deadline) unless @deadline.nil?
        end

        def prefixal_scope?
          !@is_prefixal_scope.nil?
        end

        def insert_only?
          !@insert_only.nil?
        end

        def detect_mime?
          !@detect_mime.nil?
        end

        def normal_storage?
          @file_type.nil? || @file_type == StorageType.normal
        end

        def infrequent_storage?
          @file_type == StorageType.infrequent
        end

        def insert_only!
          @insert_only = true
          self
        end

        def detect_mime!
          @detect_mime = true
          self
        end

        def normal_storage!
          @file_type = StorageType.normal
          self
        end

        def infrequent_storage!
          @file_type = StorageType.infrequent
          self
        end

        def set_return(url, body: nil)
          @return_url = url
          @return_body = body
          self
        end

        def set_callback(url, host: nil, body: nil, body_type: nil)
          @callback_url = url.is_a?(Array) ? url.join(';') : url
          @callback_host = host
          @callback_body = body
          @callback_body_type = body_type
          self
        end

        def set_persistent_ops(ops, notify_url: nil, pipeline: nil)
          @persistent_ops = ops
          @persistent_notify_url = notify_url
          @persistent_pipeline = pipeline
          self
        end

        def limit_file_size(max: nil, min: nil)
          @min_file_size = min
          @max_file_size = max
          self
        end

        def limit_content_type(content_type)
          content_type = content_type.join(';') if content_type.is_a?(Array)
          @mime_limit = content_type
          self
        end

        def content_type_limit
          @mime_limit.split(';')
        end

        # rubocop:disable Naming/AccessorMethodName
        def set_file_lifetime(days:)
          @delete_after_days = days
          self
        end
        # rubocop:enable Naming/AccessorMethodName

        def file_lifetime
          Duration.new(day: @delete_after_days) unless @delete_after_days.nil?
        end

        def save_as(key:, force: true)
          @save_key = key
          @force_save_key = force
        end
        alias force_save_key? force_save_key

        def self.from_json(json)
          require 'json' unless defined?(JSON)
          hash = JSON.parse(json)
          bucket, key = hash['scope']&.split(':', 2)
          policy = if hash['isPrefixalScope'] == 1
                     new(bucket: bucket, key_prefix: key)
                   else
                     new(bucket: bucket, key: key)
                   end
          policy.save_as(key: hash['saveKey'], force: hash['forceSaveKey'])
          policy.insert_only! if hash['insertOnly'] == 1
          policy.detect_mime! if hash['detectMime'] == 1
          case hash['fileType']
          when Model::StorageType.normal, nil
            policy.normal_storage!
          when Model::StorageType.infrequent
            policy.infrequent_storage!
          else
            raise InvalidUploadToken, "Unrecognized fileType: #{hash['fileType']}"
          end
          policy.token_deadline = hash['deadline']
          policy.end_user = hash['endUser']
          policy.set_return(hash['returnUrl'], body: hash['returnBody'])
                .set_callback(hash['callbackUrl'],
                              host: hash['callbackHost'],
                              body: hash['callbackBody'],
                              body_type: hash['callbackBodyType'])
                .set_persistent_ops(hash['persistentOps'],
                                    notify_url: hash['persistentNotifyUrl'],
                                    pipeline: hash['persistentPipeline'])
                .limit_file_size(min: hash['fsizeMin'], max: hash['fsizeLimit'])
                .limit_content_type(hash['mimeLimit'])
                .set_file_lifetime(days: hash['deleteAfterDays'])
        end

        def to_h
          h = {
            scope: @scope,
            isPrefixalScope: Utils::Bool.to_int(@is_prefixal_scope, omitempty: true),
            insertOnly: Utils::Bool.to_int(@insert_only, omitempty: true),
            detectMime: Utils::Bool.to_int(@detect_mime, omitempty: true),
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
            forceSaveKey: @force_save_key,
            fsizeMin: @min_file_size,
            fsizeLimit: @max_file_size,
            mimeLimit: @mime_limit,
            deadline: @deadline&.to_i,
            deleteAfterDays: @delete_after_days&.to_i,
            fileType: @file_type&.to_i
          }
          h.each_with_object({}) do |(k, v), o|
            o[k] = v unless v.nil?
          end
        end
        alias as_json to_h

        def ==(other)
          to_h == other.to_h
        end

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
