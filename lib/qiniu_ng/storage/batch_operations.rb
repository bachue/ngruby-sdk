# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛文件的批量操作
    class BatchOperations
      def initialize(default_bucket, http_client_v1, http_client_v2, auth)
        @default_bucket = default_bucket
        @default_zone = default_bucket.zone
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
        @ops = []
      end

      def stat(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Stat.new(entry)
        self
      end

      def disable!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: true)
        self
      end

      def enable!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: false)
        self
      end

      def set_lifetime(key, bucket: @default_bucket, days:)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::SetLifetime.new(entry, days: days)
        self
      end

      def normal_storage!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.normal)
        self
      end

      def infrequent_storage!(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.infrequent)
        self
      end

      def change_mime_type(key, mime_type, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'mime_type must not be nil' if mime_type.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeMIMEType.new(entry, mime_type: mime_type)
        self
      end

      def change_meta(key, meta, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'meta must not be nil' if mime_type.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::ChangeMeta.new(entry, meta: meta)
        self
      end

      def rename_to(src_key, dest_key, force: false, bucket: @default_bucket)
        raise ArgumentError, 'src_key must not be nil' if src_key.nil?
        raise ArgumentError, 'dest_key must not be nil' if dest_key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, src_key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Move.new(entry, bucket: bucket, key: dest_key, force: force)
        self
      end

      def move_to(src_key, dest_key, force: false, src_bucket: @default_bucket, dest_bucket: @default_bucket)
        raise ArgumentError, 'src_key must not be nil' if src_key.nil?
        raise ArgumentError, 'dest_key must not be nil' if dest_key.nil?
        raise ArgumentError, 'src_bucket must not be nil' if src_bucket.nil?
        raise ArgumentError, 'dest_bucket must not be nil' if dest_bucket.nil?

        entry = Entry.new(src_bucket, src_key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Move.new(entry, bucket: dest_bucket, key: dest_key, force: force)
        self
      end

      def copy_to(src_key, dest_key, force: false, src_bucket: @default_bucket, dest_bucket: @default_bucket)
        raise ArgumentError, 'src_key must not be nil' if src_key.nil?
        raise ArgumentError, 'dest_key must not be nil' if dest_key.nil?
        raise ArgumentError, 'src_bucket must not be nil' if src_bucket.nil?
        raise ArgumentError, 'dest_bucket must not be nil' if dest_bucket.nil?

        entry = Entry.new(src_bucket, src_key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Copy.new(entry, bucket: dest_bucket, key: dest_key, force: force)
        self
      end

      def delete(key, bucket: @default_bucket)
        raise ArgumentError, 'key must not be nil' if key.nil?
        raise ArgumentError, 'bucket must not be nil' if bucket.nil?

        entry = Entry.new(bucket, key, @http_client_v1, @http_client_v2, @auth)
        @ops << Op::Delete.new(entry)
        self
      end

      def do(zone: @default_zone, https: nil, **options)
        results = []
        ops = @ops
        until ops.size.zero?
          current_ops = ops[0...Config.batch_max_size]
          ops = ops[Config.batch_max_size..-1] || []
          results += @http_client_v1.post('/batch', rs_url(zone, https),
                                          body: Faraday::Utils.build_query(current_ops.map { |op| ['op', op.to_s] }),
                                          **options).body
        end
        Results.new(@ops, results)
      end

      # 批量操作结果
      class Results
        # 单个操作结果
        class Result
          attr_reader :op, :code, :response
          def initialize(operation, code, response)
            @op = operation
            @code = code
            @response = operation.parse(response) if operation.respond_to?(:parse)
          end

          def success?
            (200...400).include?(@code)
          end
        end

        include Enumerable

        def initialize(ops, results)
          @results = ops.each_with_index.map do |op, index|
            Result.new(op, results[index]['code'], results[index]['data'])
          end
        end

        def each
          if block_given?
            @results.each { |result| yield result }
          else
            @results.each
          end
        end

        def size
          @results.size
        end
      end

      private

      def rs_url(zone, https)
        https = Config.use_https if https.nil?
        zone.rs_url(https)
      end
    end
  end
end
