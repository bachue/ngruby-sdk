# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛上传策略
      #
      # @see https://developer.qiniu.com/kodo/manual/1206/put-policy
      # @!attribute [r] scope
      #   @return [String] 上传目标范围
      # @!attribute [r] bucket
      #   @return [String] 存储空间名称
      # @!attribute [r] key
      #   @return [String] 文件名或文件名前缀
      # @!attribute [r] return_url
      #   @return [String] Web 端文件上传成功后，浏览器执行 303 跳转的 URL。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-return-url]
      # @!attribute [r] return_body
      #   @return [String] 文件名或文件名前缀，上传成功后，自定义七牛云最终返回给上传端的数据。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-return-body]
      # @!attribute [r] callback_urls
      #   @return [Array<String>] 上传成功后，将回调业务服务器的 URL 列表。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-url]
      # @!attribute [r] callback_host
      #   @return [String] 上传成功后的回调 HOST。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-host]
      # @!attribute [r] callback_body
      #   @return [String] 上传成功后的回调请求的内容。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-body]
      # @!attribute [r] callback_body_type
      #   @return [String] 上传成功后的回调请求的内容类型，默认为 application/x-www-form-urlencoded。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-body-type]
      # @!attribute [r] persistent_ops
      #   @return [Array<String>] 上传成功后触发执行的预转持久化处理指令列表。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-persistent-ops]
      # @!attribute [r] persistent_notify_url
      #   @return [String] 接收持久化处理结果通知的 URL。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#putpolicy-persistentNotifyUrl]
      # @!attribute [r] persistent_pipeline
      #   @return [String] 转码队列名。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-persistentPipeline]
      # @!attribute [r] end_user
      #   @return [String] 唯一属主标识
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-end-user]
      # @!attribute [r] min_file_size
      #   @return [Integer] 限定上传文件大小最小值，单位为字节
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-fsize-min]
      # @!attribute [r] max_file_size
      #   @return [Integer] 限定上传文件大小最大值，单位为字节
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#fsize-limit]
      # @!attribute [r] save_key
      #   @return [String] 自定义文件名，force_save_key 为 false 时，当用户上传的时候没有主动指定 key 时才会使用 save_key，
      #     而当 force_save_key 为 true 时，将强制将文件命名为 save_key。
      #     {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#save-key]
      # @!attribute [r] force_save_key
      #   @return [Boolean] save_key 优先级设置
      class UploadPolicy
        # 上传策略解析错误
        module Errors
          # 上传凭证不合法，无法从中解析出上传策略
          class InvalidUploadToken < ArgumentError
          end
        end

        attr_reader :scope, :bucket, :key
        attr_reader :return_url, :return_body
        attr_reader :callback_urls, :callback_host, :callback_body, :callback_body_type
        attr_reader :persistent_ops, :persistent_notify_url, :persistent_pipeline
        attr_accessor :end_user
        attr_reader :min_file_size, :max_file_size
        attr_reader :save_key, :force_save_key

        # @!visibility private
        def initialize(bucket:, key: nil, key_prefix: nil)
          @bucket = bucket
          @key = key || key_prefix
          @scope = Entry.new(bucket: @bucket, key: @key).to_s
          @is_prefixal_scope = key_prefix.nil? ? nil : true
          @save_key = nil
          @force_save_key = nil
          @insert_only = nil
          @detect_mime = nil
          @file_type = nil
          @deadline = nil
          @end_user = nil
          @return_url = nil
          @return_body = nil
          @callback_urls = nil
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
          self.token_lifetime = Config.default_upload_token_lifetime
        end

        # 设置上传凭证有效期
        #
        # @param [Integer] lifetime 上传凭证有效期，单位为秒
        def token_lifetime=(lifetime)
          @deadline = [Time.now.to_i + lifetime.to_i, (1 << 32) - 1].min
        end

        # rubocop:disable Naming/AccessorMethodName

        # 设置上传凭证有效期
        #
        # @example
        #   token = entry.upload_token do |policy|
        #             policy.set_token_lifetime(day: 1) }
        #           end
        #   entry.bucket.upload(filepath: '/path/to/file', upload_token: token)
        #
        # @param [Integer, Hash, QiniuNg::Duration] args 上传凭证有效期，可以用 Hash 表示
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def set_token_lifetime(*args)
          self.token_lifetime = Utils::Duration.new(*args)
          self
        end
        # rubocop:enable Naming/AccessorMethodName

        # 上传凭证有效期
        #
        # 注意，上传策略中其实只存储了上传凭证的过期时间。
        # 如果调用 #token_lifetime= 或 #set_token_lifetime，SDK 将会自动计算出过期时间并设置在上传凭证上。
        # 此时，如果再调用 #token_lifetime，得到的结果几乎总是小于先前设置的有效期长度，
        # 因为该结果是由上传凭证中的过期时间减去当前时间得到的。
        #
        # @return [QiniuNg::Duration, nil] 返回有效期长度，如果为 nil 表示从未设置过有效期
        def token_lifetime
          Utils::Duration.new(seconds: Time.at(@deadline) - Time.now) unless @deadline.nil?
        end

        # 设置上传凭证过期时间
        #
        # @param [Time] deadline 上传凭证过期时间
        def token_deadline=(deadline)
          @deadline = [deadline.to_i, (1 << 32) - 1].min
        end

        # 设置上传凭证过期时间
        #
        # @return [Time] 返回过期时间，如果为 nil 表示从未设置过有效期
        def token_deadline
          Time.at(@deadline) unless @deadline.nil?
        end

        # 判断 #key 表示的是文件名前缀还是文件名
        #
        # @return [Boolean] #key 是否表示文件名前缀
        def prefixal_scope?
          !@is_prefixal_scope.nil?
        end

        # 是否仅能以新增模式上传文件
        #
        # @return [Boolean] 是否仅能以新增模式上传文件
        def insert_only?
          !@insert_only.nil?
        end

        # 是否自动侦测上传文件的 MIME 类型？
        # 如果为 true，表示自动侦测，并忽略用户在上传时传入的 MIME 类型参数。
        # 否则，只在当用户上传文件时没有传入的 MIME 类型参数时，才会自动侦测。
        #
        # @return [Boolean] 是否自动侦测上传文件的 MIME 类型
        def detect_mime?
          !@detect_mime.nil?
        end

        # 是否使用标准存储
        #
        # @return [Boolean] 是否使用标准存储
        def normal_storage?
          @file_type.nil? || @file_type == StorageType.normal
        end

        # 是否使用低频存储
        #
        # @return [Boolean] 是否使用低频存储
        def infrequent_storage?
          @file_type == StorageType.infrequent
        end

        # 仅能以新增模式上传文件
        #
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def insert_only!
          @insert_only = true
          self
        end

        # 自动侦测上传文件的 MIME 类型，忽略用户在上传时传入的 MIME 类型参数。
        #
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def detect_mime!
          @detect_mime = true
          self
        end

        # 使用标准存储
        #
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def normal_storage!
          @file_type = StorageType.normal
          self
        end

        # 使用低频存储
        #
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def infrequent_storage!
          @file_type = StorageType.infrequent
          self
        end

        # 要求 Web 端文件上传成功后，浏览器执行 303 跳转
        #
        # @param [String] url 浏览器执行 303 跳转时的 URL
        # @param [String] body 上传成功后，自定义七牛云最终返回给上传端的数据
        #
        # @see https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-return-url
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def set_return(url, body: nil)
          @return_url = url
          @return_body = body
          self
        end

        # 上传成功后，将回调业务服务器。
        #
        # @param [String] urls 回调业务服务器的 URL 列表
        # @param [String] host 回调 HOST
        # @param [String] body 回调请求的内容
        # @param [String] body_type 回调请求的内容类型，默认为 application/x-www-form-urlencoded
        #
        # @see https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-url
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def set_callback(urls, host: nil, body: nil, body_type: nil)
          @callback_urls = urls.is_a?(Array) ? urls : [urls] if urls
          @callback_host = host
          @callback_body = body
          @callback_body_type = body_type
          self
        end

        # 上传成功后触发执行的预转持久化处理
        #
        # @param [String, Array<String>] ops 预转持久化处理指令列表
        # @param [String] notify_url 预转持久化处理完毕后回调业务服务器的 URL
        # @param [String, Array<String>] pipeline 转码队列名
        #
        # @see https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-persistent-ops
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def set_persistent_ops(ops, notify_url: nil, pipeline: nil)
          @persistent_ops = ops.is_a?(Array) ? ops : [ops] if ops
          @persistent_notify_url = notify_url
          @persistent_pipeline = pipeline
          self
        end

        # 限定上传文件的大小范围
        #
        # @param [Integer] max 限定上传文件大小最大值，单位为字节
        # @param [Integer] min 限定上传文件大小最小值，单位为字节
        #
        # @see https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-fsize-min
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def limit_file_size(max: nil, min: nil)
          @min_file_size = min
          @max_file_size = max
          self
        end

        # 限定上传文件的 MIME 类型范围
        #
        # @param [String, Array<String>] content_type 限制上传文件类型范围
        #
        # @see https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-mime-limit
        # @return [QiniuNg::Storage::Model::UploadPolicy] 返回上下文
        def limit_content_type(content_type)
          content_type = content_type.join(';') if content_type.is_a?(Array)
          @mime_limit = content_type
          self
        end

        # 获取上传文件的 MIME 类型限定范围
        # @return [Array<String>] 限制的上传文件类型范围
        def content_type_limit
          @mime_limit.split(';')
        end

        # rubocop:disable Naming/AccessorMethodName

        # 设置上传文件的生命周期
        # @param [String] days 指定被删除的时间
        def set_file_lifetime(days:)
          @delete_after_days = days
          self
        end

        # rubocop:enable Naming/AccessorMethodName

        # 获取上传文件的生命周期
        # @return [QiniuNg::Duration] 上传文件的生命周期，如果为 nil 表示从未设置过文件的生命周期
        def file_lifetime
          Utils::Duration.new(day: @delete_after_days) unless @delete_after_days.nil?
        end

        # 设置上传文件的文件名
        #
        # @param [String] key 自定义文件名。
        #   如果传入的 force 为 false 时，当用户上传的时候没有主动指定 key 时才会使用 key，
        #   而当 force 为 true 时，将强制将文件命名为 key。
        #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#save-key]
        def save_as(key, force: false)
          @save_key = key
          @force_save_key = force
        end
        alias force_save_key? force_save_key

        # @!visibility private
        def self.from_json(json)
          hash = Config.default_json_unmarshaler.call(json)
          bucket, key = hash['scope']&.split(':', 2)
          policy = if hash['isPrefixalScope'] == 1
                     new(bucket: bucket, key_prefix: key)
                   else
                     new(bucket: bucket, key: key)
                   end
          policy.save_as(hash['saveKey'], force: hash['forceSaveKey'])
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
                .set_callback(hash['callbackUrl']&.split(';'),
                              host: hash['callbackHost'],
                              body: hash['callbackBody'],
                              body_type: hash['callbackBodyType'])
                .set_persistent_ops(hash['persistentOps']&.split(';'),
                                    notify_url: hash['persistentNotifyUrl'],
                                    pipeline: hash['persistentPipeline'])
                .limit_file_size(min: hash['fsizeMin'], max: hash['fsizeLimit'])
                .limit_content_type(hash['mimeLimit'])
                .set_file_lifetime(days: hash['deleteAfterDays'])
        end

        # @!visibility private
        def to_h
          h = {
            scope: @scope,
            isPrefixalScope: Utils::Bool.to_int(@is_prefixal_scope, omitempty: true),
            insertOnly: Utils::Bool.to_int(@insert_only, omitempty: true),
            detectMime: Utils::Bool.to_int(@detect_mime, omitempty: true),
            endUser: @end_user,
            returnUrl: @return_url,
            returnBody: @return_body,
            callbackUrl: @callback_urls&.join(';'),
            callbackHost: @callback_host,
            callbackBody: @callback_body,
            callbackBodyType: @callback_body_type,
            persistentOps: @persistent_ops&.join(';'),
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

        # @!visibility private
        def ==(other)
          to_h == other.to_h
        end

        # @!visibility private
        def to_json(*args)
          Config.default_json_marshaler.call(as_json, *args)
        end
      end
      PutPolicy = UploadPolicy
    end
  end
end
