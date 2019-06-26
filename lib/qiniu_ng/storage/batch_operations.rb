# frozen_string_literal: true

module QiniuNg
  module Storage
    # 七牛文件的批量操作
    class BatchOperations
      def initialize(default_bucket, http_client, auth)
        @default_bucket = default_bucket
        @default_zone = default_bucket.zone
        @http_client = http_client
        @auth = auth
        @ops = []
      end

      def stat(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::Stat.new(entry)
        self
      end

      def disable!(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: true)
        self
      end

      def enable!(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeStatus.new(entry, disabled: false)
        self
      end

      def set_lifetime(key, bucket: @default_bucket, days:)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::SetLifetime.new(entry, days: days)
        self
      end

      def normal_storage!(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.normal)
        self
      end

      def infrequent_storage!(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeType.new(entry, type: Model::StorageType.infrequent)
        self
      end

      def change_mime_type(key, mime_type, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeMIMEType.new(entry, mime_type: mime_type)
        self
      end

      def change_meta(key, meta, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::ChangeMeta.new(entry, meta: meta)
        self
      end

      def rename_to(src_key, dest_key, force: false, bucket: @default_bucket)
        entry = Entry.new(bucket, src_key, @http_client, @auth)
        @ops << Op::Move.new(entry, bucket: bucket, key: dest_key, force: force)
        self
      end

      def move_to(src_key, dest_key, force: false, src_bucket: @default_bucket, dest_bucket: @default_bucket)
        entry = Entry.new(src_bucket, src_key, @http_client, @auth)
        @ops << Op::Move.new(entry, bucket: dest_bucket, key: dest_key, force: force)
        self
      end

      def copy_to(src_key, dest_key, force: false, src_bucket: @default_bucket, dest_bucket: @default_bucket)
        entry = Entry.new(src_bucket, src_key, @http_client, @auth)
        @ops << Op::Copy.new(entry, bucket: dest_bucket, key: dest_key, force: force)
        self
      end

      def delete(key, bucket: @default_bucket)
        entry = Entry.new(bucket, key, @http_client, @auth)
        @ops << Op::Delete.new(entry)
        self
      end

      def do(zone: @default_zone, https: nil, **options)
        results = []
        ops = @ops
        until ops.size.zero?
          current_ops = ops[0...Config.batch_max_size]
          ops = ops[Config.batch_max_size..-1] || []
          results += @http_client.post("#{rs_url(zone, https)}/batch",
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
        zone.rs(https)
      end
    end
  end
end
