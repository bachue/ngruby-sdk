# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的批处理操作
    class BatchOperations
      # @!visibility private
      def initialize(default_bucket, http_client_v1, http_client_v2, auth, raise_if_partial_ok)
        @default_bucket = default_bucket
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
        @ops = []
        @raise_if_partial_ok = raise_if_partial_ok
      end

      # 获取文件元信息
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def stat(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Stat.new(entry)
        self
      end

      # 禁用文件
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def disable!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: true)
        self
      end

      # 启用文件
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def enable!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: false)
        self
      end

      # 设置文件生命周期，该文件将在生命周期结束后被自动删除
      #
      # @param [String] key 文件名
      # @param [Integer] days 文件生命周期
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def set_lifetime(key, bucket: @default_bucket, days:)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::SetLifetime.new(entry, days: days)
        self
      end

      # 设置文件存储类型为标准存储
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def normal_storage!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.normal)
        self
      end

      # 设置文件存储类型为低频存储
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def infrequent_storage!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.infrequent)
        self
      end

      # 设置文件的 MIME 类型
      #
      # @param [String] key 文件名
      # @param [String] mime_type 文件 MIME 类型
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def change_mime_type(key, mime_type, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'mime_type must not be nil' if mime_type.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeMIMEType.new(entry, mime_type: mime_type)
        self
      end

      # 设置文件的 HTTP Header 信息
      #
      # @param [String] key 文件名
      # @param [Hash] meta 文件的 HTTP Header 信息
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def change_meta(key, meta, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'meta must not be nil' if mime_type.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeMeta.new(entry, meta: meta)
        self
      end

      # 重命名文件
      #
      # @param [String] from 源文件名
      # @param [String] to 目标文件名
      # @param [Boolean] force 是否覆盖，当目标文件名已经存在时
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def rename(from:, to:, force: false, bucket: @default_bucket)
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, from, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Move.new(entry, bucket: bucket, key: to, force: force)
        self
      end

      # 移动文件
      #
      # @param [String] from 源文件名
      # @param [String] to 目标文件名
      # @param [QiniuNg::Storage::Bucket] from_bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @param [QiniuNg::Storage::Bucket] to_bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @param [Boolean] force 是否覆盖，当目标文件名在目标存储空间中已经存在时
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def move(from:, to:, force: false, from_bucket: @default_bucket, to_bucket: @default_bucket)
        raise ArgumentError, 'from_bucket must not be nil' if from_bucket.nil?
        raise ArgumentError, 'to_bucket must not be nil' if to_bucket.nil?

        entry = Entry.new(from_bucket, from, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Move.new(entry, bucket: to_bucket, key: to, force: force)
        self
      end

      # 复制文件
      #
      # @param [String] from 源文件名
      # @param [String] to 目标文件名
      # @param [QiniuNg::Storage::Bucket] from_bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @param [QiniuNg::Storage::Bucket] to_bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @param [Boolean] force 是否覆盖，当目标文件名在目标存储空间中已经存在时
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def copy(from:, to:, force: false, from_bucket: @default_bucket, to_bucket: @default_bucket)
        raise ArgumentError, 'from_bucket must not be nil' if from_bucket.nil?
        raise ArgumentError, 'to_bucket must not be nil' if to_bucket.nil?

        entry = Entry.new(from_bucket, from, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Copy.new(entry, bucket: to_bucket, key: to, force: force)
        self
      end

      # 删除文件
      #
      # @param [String] key 文件名
      # @param [QiniuNg::Storage::Bucket] bucket 存储空间，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @return [QiniuNg::Storage::BatchOperations] 返回上下文
      # @raise [ArgumentError] key 或 bucket 为 nil
      def delete(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Delete.new(entry)
        self
      end

      # 发送批处理操作请求
      #
      # @param [QiniuNg::Zone] zone 存储空间所在区域，如果 BatchOperations 对象被创建于存储空间，则该参数可以省略
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::BatchOperations::Results] 返回批处理操作结果
      # @raise [ArgumentError] zone 为 nil
      def do(zone: @default_bucket&.zone, https: nil, **options)
        raise ArgumentError, 'zone must not be nil' if zone.nil?

        results = []
        ops = @ops
        until ops.size.zero?
          current_ops = ops[0...Config.batch_max_size]
          ops = ops[Config.batch_max_size..-1] || []
          resp = @http_client_v1.post('/batch', rs_url(zone, https),
                                      body: Faraday::Utils.build_query(current_ops.map { |op| ['op', op.to_s] }),
                                      **options)
          raise HTTP::PartialOK, response_values(resp) if resp.status == 298 && @raise_if_partial_ok

          results += resp.body
        end
        Results.new(@ops, results)
      end

      # 批量操作结果
      class Results
        # 单个操作结果
        # @!attribute [r] op
        #   @return [String] 操作名称
        # @!attribute [r] code
        #   @return [String] 操作结果代码
        # @!attribute [r] response
        #   @return [Integer] 操作结果
        class Result
          extend Forwardable
          attr_reader :op, :code, :response

          # @!visibility private
          def initialize(operation, code, response)
            @op = operation
            @code = code
            @response = operation.parse(response)
          end

          # 操作是否成功
          # @return [Boolean] 操作是否成功
          def success?
            (200...400).include?(@code)
          end
          alias successful? success?

          # 操作是否失败
          # @return [Boolean] 操作是否成功
          def failed?
            !success?
          end

          # @!visibility private
          def method_missing(method, *args, &block)
            return @response.send(method, *args, &block) if @response.respond_to?(method)

            super
          end
        end

        include Enumerable

        # @!visibility private
        def initialize(ops, results)
          @results = ops.each_with_index.map do |op, index|
            Result.new(op, results[index]['code'], results[index]['data'])
          end
        end

        # 获取操作结果迭代器
        # @return [Enumerator] 返回迭代器
        def each
          if block_given?
            @results.each { |result| yield result }
          else
            @results.each
          end
        end

        # 获取操作结果数量
        # @return [Integer] 返回操作结果数量
        def size
          @results.size
        end
      end

      private

      def rs_url(zone, https)
        https = Config.use_https if https.nil?
        zone.rs_url(https)
      end

      def response_values(response)
        { status: response.status, headers: response.headers, body: response.body }
      end
    end
  end
end
