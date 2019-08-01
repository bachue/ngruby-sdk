# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # 七牛存储空间
    #
    # @example
    #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
    #   bucket = client.bucket('<Bucket Name>')
    #   bucket_on_huabei = client.bucket('<Bucket Name>', zone: QiniuNg::Zone.huabei)
    #
    class Bucket
      extend Forwardable

      # @!visibility private
      def initialize(bucket_name, zone, http_client_v1, http_client_v2, auth, domains)
        @bucket_name = bucket_name.freeze
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
        @info_cache = nil
        @info_cache_expire_at = nil
        @info_lock = Concurrent::ReadWriteLock.new

        @zone = zone.freeze
        @zone_lock = Concurrent::ReadWriteLock.new

        @domains = normalize_domains(domains).freeze
        @domains_lock = Concurrent::ReadWriteLock.new

        @uploader = nil
        @uploader_lock = Concurrent::ReadWriteLock.new
      end

      # 获取存储空间名称
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.create_bucket('<New Bucket Name>', zone: :z2)
      #   expect(bucket.name).to eq('<New Bucket Name>')
      #
      # @return [String] name 存储空间名称
      def name
        @bucket_name
      end
      alias to_s name

      # 获取存储空间所在区域实例
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.create_bucket('<New Bucket Name>', zone: :z2)
      #   expect(bucket.zone.name).to eq('z2')
      #
      # @return [QiniuNg::Zone] 存储空间区域
      def zone
        zone = @zone_lock.with_read_lock { @zone }
        return zone if zone

        @zone_lock.with_write_lock do
          @zone ||= Common::Zone.auto.query(access_key: @auth.access_key, bucket: @bucket_name).freeze
        end
      end

      # 设置存储空间所在区域实例
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.zone = QiniuNg::Zone.huabei
      #
      # @param [QiniuNg::Zone] zone 存储空间区域
      def zone=(zone)
        @zone_lock.with_write_lock { @zone = zone.freeze }
      end

      # 获取存储空间的下载域名列表
      #
      # 如果在初始化 Bucket 时设置下载域名，该方法将会返回设置的下载域名列表。否则，将会获取所有绑定在七牛存储空间上的下载域名列表
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>', domains: %w[download.qiniuapp.com])
      #   expect(bucket.zone.domains).to match_array(%w[download.qiniuapp.com])
      #
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<String>] 返回下载域名列表
      def domains(api_zone: nil, https: nil, **options)
        domains = @domains_lock.with_read_lock { @domains }
        return domains if domains

        @domains_lock.with_write_lock do
          @domains ||= begin
            params = { tbl: @bucket_name }
            @http_client_v1.get('/v6/domain/list', get_api_url(api_zone, https), params: params, **options).body.freeze
          end
          @domains
        end
      end

      # 设置存储空间下载域名列表
      #
      # 该方法不会改变绑定在七牛存储空间上的域名列表
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.domains = %w[download.qiniuapp.com]
      def domains=(domains)
        domains = normalize_domains(domains).freeze
        @domains_lock.with_write_lock { @domains = domains }
      end

      # 设置存储空间的镜像存储
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.set_image('https://mars-assets.qnssl.com')
      #
      # @param [String] source_url 镜像源地址
      # @param [String] source_host 回源 HOST 地址
      #   {参数文档}[https://developer.qiniu.com/fusion/kb/4064/understanding-and-setting-up-the-way-back-to-the-source-host]
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def set_image(source_url, uc_url: nil, source_host: nil, https: nil, **options)
        encoded_url = Base64.urlsafe_encode64(source_url)
        path = "/image/#{@bucket_name}/from/#{encoded_url}"
        path += "/host/#{Base64.urlsafe_encode64(source_host)}" unless source_host.nil? || source_host.empty?
        @http_client_v1.post(path, uc_url || get_uc_url(https), **options)
        expire_info!
        nil
      end

      # 取消存储空间的镜像存储设置
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.unset_image
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def unset_image(uc_url: nil, https: nil, **options)
        @http_client_v1.post("/unimage/#{@bucket_name}", uc_url || get_uc_url(https), **options)
        expire_info!
        nil
      end

      # 存储空间的镜像存储设置
      #
      # @attr_reader [String] source_url 镜像源地址
      # @attr_reader [String] source_host 回源 HOST 地址
      #   {参数文档}[https://developer.qiniu.com/fusion/kb/4064/understanding-and-setting-up-the-way-back-to-the-source-host]
      ImageInfo = Struct.new(:source_url, :source_host)

      # 获取存储空间的镜像存储设置
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Bucket::ImageInfo, nil] 镜像存储设置，如果没有设置过则返回 nil
      def image(uc_url: nil, https: nil, **options)
        result = info(uc_url: uc_url, https: https, **options)
        ImageInfo.new(result['source'], result['host']) if result['source']
      end

      # 设置存储空间为公开空间
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.public!
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def public!(uc_url: nil, https: nil, **options)
        update_acl(private_access: false, uc_url: uc_url, https: https, **options)
      end

      # 设置存储空间为私有空间
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.private!
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def private!(uc_url: nil, https: nil, **options)
        update_acl(private_access: true, uc_url: uc_url, https: https, **options)
      end

      # 判断存储空间是否是私有空间
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   is_private = client.bucket('<Bucket Name>').private?
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Boolean] 是否为私有空间
      def private?(uc_url: nil, https: nil, **options)
        info(uc_url: uc_url, https: https, **options)['private'] == 1
      end

      # 数据处理样式分隔符
      #
      # @see https://developer.qiniu.com/dora/manual/1204/processing-mechanism
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [String] 返回样式分隔符
      def style_separator(uc_url: nil, https: nil, **options)
        info(uc_url: uc_url, https: https, **options)['separator'].freeze
      end

      # 开启存储空间的默认首页功能
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   client.bucket('<Bucket Name>').enable_index_page
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def enable_index_page(uc_url: nil, https: nil, **options)
        set_index_page(true, uc_url: uc_url, https: https, **options)
      end

      # 关闭存储空间的默认首页功能
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   client.bucket('<Bucket Name>').disable_index_page
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def disable_index_page(uc_url: nil, https: nil, **options)
        set_index_page(false, uc_url: uc_url, https: https, **options)
      end

      # 判断存储空间的默认首页功能是否打开
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   client.bucket('<Bucket Name>').has_index_page?
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def has_index_page?(uc_url: nil, https: nil, **options)
        info(uc_url: uc_url, https: https, **options)['no_index_page'].zero?
      end

      # 获取存储空间中的一个文件实例
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   client.bucket('<Bucket Name>').entry('key')
      #
      # @param [String] key 文件名称
      # @return [QiniuNg::Storage::Entry] 返回存储空间中的一个文件实例
      def entry(key)
        Entry.new(self, key, @http_client_v1, @http_client_v2, @auth)
      end

      # 获取异步抓取任务结果
      #
      # 根据异步抓取任务 ID 获取结果
      #
      # @example
      #   job = client.bucket('<Bucket Name>').entry('key').async_fetch_from('<URL>', md5: '<Resource MD5>')
      #   saved_async_fetch_job_id = job.id
      #
      #   job = bucket.query_async_fetch_result(saved_async_fetch_job_id)
      #   expect(job.done?).to be true
      #
      # @param [String] id 异步抓取任务 ID
      # @return [QiniuNg::Storage::Model::AsyncFetchJob] 返回异步抓取任务
      def query_async_fetch_result(id)
        Model::AsyncFetchJob.new(self, @http_client_v2, id)
      end

      # 获取文件处理结果
      #
      # 根据异步抓取任务 ID 获取结果
      #
      # @param [String, QiniuNg::Processing::PersistentID] persistent_id 持久化 ID
      # @return [QiniuNg::Processing::PfopResults] 持久化结果
      def query_processing_result(persistent_id, api_zone: nil, https: nil, **options)
        Processing::PersistentID.new(persistent_id.to_s, @http_client_v1, self)
                                .get(api_zone: api_zone, https: https, **options)
      end

      # 遍历存储空间中的文件，获取迭代器
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   keys = client.bucket('<Bucket Name>').files.map { |entry| entry.key }
      #
      # @param [String] prefix 仅返回文件名前缀为指定字符串的文件
      # @param [Integer] limit 限制最多返回的文件数量，默认为无上限
      # @param [String] marker 设置遍历文件使用的标记，该标记必须合法
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Enumerable] 返回一个{迭代器}[https://ruby-doc.org/core-2.6/Enumerable.html]实例
      def files(rsf_zone: nil, prefix: nil, limit: nil, marker: nil, https: nil, **options)
        FilesIterator.new(@http_client_v1, @http_client_v2, @auth,
                          self, prefix, limit, marker, rsf_zone, https, options)
      end

      # @!visibility private
      class FilesIterator
        include Enumerable
        extend Forwardable

        # @!visibility private
        def initialize(http_client_v1, http_client_v2, auth, bucket, prefix, limit, marker, rsf_zone, https, options)
          @http_client_v1 = http_client_v1
          @http_client_v2 = http_client_v2
          @auth = auth
          @bucket = bucket
          @prefix = prefix
          @limit = limit
          @marker = marker
          @got = 0
          @rsf_url = get_rsf_url(rsf_zone, https)
          @options = options
        end

        def_delegators :enumerator, :each

        private

        def enumerator
          Enumerator.new do |yielder|
            loop do
              params = { bucket: @bucket.name }
              params[:prefix] = @prefix unless @prefix.nil? || @prefix.empty?
              params[:limit] = @limit unless @limit.nil? || !@limit.positive?
              params[:marker] = @marker unless @marker.nil? || @marker.empty?
              body = @http_client_v1.post('/list', @rsf_url, params: params, **@options).body
              @marker = body['marker']
              break if body['items'].size.zero?

              body['items'].each do |item|
                break unless @limit.nil? || @got < @limit

                entry = Entry.new(@bucket, item['key'], @http_client_v1, @http_client_v2, @auth)
                yielder << Model::ListedEntry.new(
                  entry, mime_type: item['mimeType'], hash: item['hash'], file_size: item['fsize'],
                         put_at: Time.at(0, item['putTime'].to_f / 10), end_user: item['endUser'],
                         storage_type: item['type'], status: item['status']
                )
                @got += 1
              end
              break if @marker.nil? || @marker.empty? || (!@limit.nil? && @got >= @limit)
            end
          end
        end

        def get_rsf_url(rsf_zone, https)
          https = Config.use_https if https.nil?
          rsf_zone ||= @bucket.zone
          rsf_zone.rsf_url(https)
        end
      end

      # 获取存储空间的上传器，用于上传文件
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket.uploader.upload(filepath: '/path/to/file', upload_token: bucket.upload_token)
      #
      # @example Uploader 中的所有方法都已经被委托给 Bucket 直接调用，因此上面一行代码也可以被重写为
      #   bucket.upload(filepath: '/path/to/file', upload_token: bucket.upload_token)
      #
      # @param [Integer] block_size 当使用分片方式上传文件时，设置每个分片的尺寸。单位为字节。该尺寸必须是 4 MB 的整数倍，默认为使用全局设置中的分片尺寸
      # @return [QiniuNg::Storage::Uploader] 返回存储空间的上传器
      def uploader(block_size: Config.default_upload_block_size)
        uploader = @uploader_lock.with_read_lock { @uploader }
        return uploader if block_size && uploader&.block_size == block_size

        @uploader_lock.with_write_lock do
          @uploader ||= Uploader.new(self, @http_client_v1, block_size: block_size)
        end
      end
      def_delegators :uploader, :upload

      # 生成存储空间的上传凭证
      #
      # 该方法如果不传入任何参数，效果同 #upload_token_for_bucket；
      # 如果传入 key 参数，效果同 #upload_token_for_key(key)；
      # 如果传入 key_prefix 参数，效果同 #upload_token_for_key_prefix(key_prefix)；
      #
      # @see https://developer.qiniu.com/kodo/manual/1208/upload-token
      # @example
      #   bucket.upload(filepath: '/path/to/file', upload_token: bucket.upload_token)
      #
      # @param [String] key 获取仅能被用来上传文件名为指定字符串的文件。该参数与 key_prefix 不要同时使用
      # @param [String] key_prefix 获取仅能被用来上传文件名的前缀为指定字符串的文件。该参数与 key 不要同时使用
      # @yield [policy] 在生成上传凭证前对生成的上传策略进行修改
      # @yieldparam policy [QiniuNg::Storage::Model::UploadPolicy] 生成的上传策略
      # @return [QiniuNg::Storage::UploadToken] 返回存储空间的上传凭证
      def upload_token(key: nil, key_prefix: nil, &block)
        return upload_token_for_key(key, &block) unless key.nil?
        return upload_token_for_key_prefix(key_prefix, &block) unless key_prefix.nil?

        upload_token_for_bucket(&block)
      end

      # 生成存储空间的上传凭证
      #
      # @example
      #   token = bucket.upload_token_for_bucket do |policy|
      #             policy.set_token_lifetime(day: 1) }
      #           end
      #   bucket.upload(filepath: '/path/to/file', upload_token: token)
      #
      # @yield [policy] 在生成上传凭证前对生成的上传策略进行修改
      # @yieldparam policy [QiniuNg::Storage::Model::UploadPolicy] 生成的上传策略
      # @return [QiniuNg::Storage::UploadToken] 返回存储空间的上传凭证
      def upload_token_for_bucket
        policy = Model::UploadPolicy.new(bucket: @bucket_name)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      # 生成存储空间的上传凭证，仅能由于上传指定文件名的文件
      #
      # @example
      #   token = bucket.upload_token_for_key('key1') do |policy|
      #             policy.set_token_lifetime(day: 1)
      #           end
      #   bucket.upload(filepath: '/path/to/file', key: 'key1', upload_token: token)
      #
      # @param [String] key 限制上传的文件名
      # @yield [policy] 在生成上传凭证前对生成的上传策略进行修改
      # @yieldparam policy [QiniuNg::Storage::Model::UploadPolicy] 生成的上传策略
      # @return [QiniuNg::Storage::UploadToken] 返回存储空间的上传凭证
      def upload_token_for_key(key)
        policy = Model::UploadPolicy.new(bucket: @bucket_name, key: key)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      # 生成存储空间的上传凭证，仅能由于上传指定文件名前缀的文件
      #
      # @example
      #   token = bucket.upload_token_for_key_prefix('key') do |policy|
      #     policy.set_token_lifetime(day: 1)
      #   end
      #   bucket.upload(filepath: '/path/to/file', key: 'key2', upload_token: token)
      #
      # @param [String] key_prefix 限制上传的文件名的前缀
      # @yield [policy] 在生成上传凭证前对生成的上传策略进行修改
      # @yieldparam policy [QiniuNg::Storage::Model::UploadPolicy] 生成的上传策略
      # @return [QiniuNg::Storage::UploadToken] 返回存储空间的上传凭证
      def upload_token_for_key_prefix(key_prefix)
        policy = Model::UploadPolicy.new(bucket: @bucket_name, key_prefix: key_prefix)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      # 对存储空间内的文件发送批处理操作
      # @example
      #   results = bucket.batch do |batch|
      #               batch.stat('key1')
      #               batch.stat('key2')
      #               batch.stat('key3')
      #             end
      #
      # @param [Bool] raise_if_partial_ok 如果部分操作发生错误，是否会抛出异常
      # @param [Bool] https 批处理操作是否使用 HTTPS 协议发送
      # @param [Hash] options 额外的 Faraday 参数
      # @yield [batch] 作为批处理操作的上下文
      # @yieldparam batch [QiniuNg::Storage::BatchOperations] 批处理操作的上下文
      # @return [QiniuNg::Storage::BatchOperations::Results] 批处理操作结果
      def batch(raise_if_partial_ok: false, https: nil, **options)
        op = BatchOperations.new(self, @http_client_v1, @http_client_v2, @auth, raise_if_partial_ok)
        return op unless block_given?

        yield op
        op.do(https: https, **options)
      end

      # 对存储空间内的文件发送批处理操作，如果部分操作发生异常，将会抛出 QiniuNg::HTTP::PartialOK 异常
      # @example
      #   results = bucket.batch! do |batch|
      #               batch.stat('key1')
      #               batch.stat('key2')
      #               batch.stat('key3')
      #             end
      #
      # @param [Bool] https 批处理操作是否使用 HTTPS 协议发送
      # @param [Hash] options 额外的 Faraday 参数
      # @raise [QiniuNg::HTTP::PartialOK] 如果部分操作发生异常
      # @yield [batch] 作为批处理操作的上下文
      # @yieldparam batch [QiniuNg::Storage::BatchOperations] 批处理操作的上下文
      # @return [QiniuNg::Storage::BatchOperations::Results] 批处理操作结果
      def batch!(https: nil, **options, &block)
        batch(raise_if_partial_ok: true, https: https, **options, &block)
      end

      # 获取存储空间的生命周期规则实例
      #
      # @example
      #   rules = bucket.life_cycle_rules
      #   rules.all
      #
      # @return [QiniuNg::Storage::LifeCycleRules] 生命周期规则实例
      def life_cycle_rules
        LifeCycleRules.new(self, @http_client_v1)
      end

      # 获取存储空间的事件规则实例
      #
      # @example
      #   rules = bucket.bucket_event_rules
      #   rules.all
      #
      # @return [QiniuNg::Storage::BucketEventRules] 事件规则实例
      def bucket_event_rules
        BucketEventRules.new(self, @http_client_v1)
      end

      # 获取存储空间的跨域规则实例
      #
      # @example
      #   rules = bucket.cors_rules
      #   rules.all
      #
      # @return [QiniuNg::Storage::CORSRules] 跨域规则实例
      def cors_rules
        CORSRules.new(self, @http_client_v1)
      end

      # 启用存储空间的源站保护
      #
      # @example
      #   bucket.enable_original_protection
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def enable_original_protection(uc_url: nil, https: nil, **options)
        set_original_protection(true, uc_url: uc_url, https: https, **options)
      end

      # 禁用存储空间的源站保护
      #
      # @example
      #   bucket.disable_original_protection
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def disable_original_protection(uc_url: nil, https: nil, **options)
        set_original_protection(false, uc_url: uc_url, https: https, **options)
      end

      # 修改存储空间的 Cache-Control Max-Age 属性
      #
      # 如果输入 0 或负数表示设置为默认值，365 天
      #
      # @example 直接输入缓存时间，单位为秒。
      #   bucket.set_cache_max_age(86400)
      # @example 输入语义化的 Hash 参数表示时间
      #   bucket.set_cache_max_age(day: 1)
      #
      # @param [Integer, Hash, QiniuNg::Duration] args 时间长度，可以用 Hash 表示，
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      def set_cache_max_age(args, uc_url: nil, https: nil, **options)
        max_age = Utils::Duration.new(args) if args.is_a?(Hash)
        params = { bucket: @bucket_name, maxAge: max_age.to_i }
        @http_client_v1.post('/maxAge', uc_url || get_uc_url(https), params: params, **options)
        expire_info!
        nil
      end

      # 获取存储空间的 Cache-Control Max-Age 属性
      #
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Duration, nil] 返回存储空间的 Cache-Control Max-Age 属性。如果返回 nil 则表示为默认值
      def cache_max_age(uc_url: nil, https: nil, **options)
        max_age_secs = info(uc_url: uc_url, https: https, **options)['max_age']
        Utils::Duration.new(seconds: max_age_secs) if max_age_secs&.positive?
      end

      # 设置存储空间的配额限制
      #
      # @example 设置空间存储量配额
      #   bucket.set_quota(size: 1 << 30)
      # @example 设置空间文件数配额
      #   bucket.set_quota(count: 100)
      #
      # @param [Integer, nil] size 设置空间存储量配额，单位为字节。如果设置为 nil 表示取消该配额。默认为不修改该配额
      # @param [Integer, nil] count 设置空间文件书配额，单位为个。如果设置为 nil 表示取消该配额。默认为不修改该配额
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Duration, nil] 返回存储空间的 Cache-Control Max-Age 属性。如果返回 nil 则表示为默认值
      def set_quota(size: 0, count: 0, api_zone: nil, https: nil, **options)
        size = -1 if size.nil?
        count = -1 if count.nil?
        @http_client_v1.post("/setbucketquota/#{@bucket_name}/size/#{size}/count/#{count}",
                             get_api_url(api_zone, https), **options)
        nil
      end

      # 存储空间的配额信息
      # @attr_reader [Integer, nil] size 空间存储量配额，单位为字节。如果为 nil 表示未设置配额
      # @attr_reader [Integer, nil] count 空间文件书配额，单位为个。如果为 nil 表示未设置该配额
      Quota = Struct.new(:size, :count)

      # 获取存储空间的配额限制
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Bucket::Quota] 返回存储空间的配额信息
      def quota(api_zone: nil, https: nil, **options)
        resp_body = @http_client_v1.get("/getbucketquota/#{@bucket_name}",
                                        get_api_url(api_zone, https), **options).body
        resp_body['size'] = nil if resp_body['size'].negative?
        resp_body['count'] = nil if resp_body['count'].negative?
        Quota.new(resp_body['size'], resp_body['count'])
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} @bucket_name=#{@bucket_name.inspect} @auth=#{@auth.inspect}" \
        " @zone=#{@zone.inspect} @domains=#{@domains.inspect}>"
      end

      private

      def set_index_page(enabled, uc_url: nil, https: nil, **options)
        no_index_page = Utils::Bool.to_int(!enabled)
        params = { bucket: @bucket_name, noIndexPage: no_index_page }
        @http_client_v1.post('/noIndexPage', uc_url || get_uc_url(https), params: params, **options)
        expire_info!
        nil
      end

      def update_acl(private_access:, uc_url: nil, https: nil, **options)
        private_access = Utils::Bool.to_int(private_access)
        params = { bucket: @bucket_name, private: private_access }
        @http_client_v1.post('/private', uc_url || get_uc_url(https), params: params, **options)
        expire_info!
        nil
      end

      def set_original_protection(enabled, uc_url: nil, https: nil, **options)
        enabled = Utils::Bool.to_int(enabled)
        @http_client_v1.post("/accessMode/#{@bucket_name}/mode/#{enabled}", uc_url || get_uc_url(https), **options)
        expire_info!
        nil
      end

      def info(uc_url: nil, https: nil, **options)
        info = @info_lock.with_read_lock { @info_cache if @info_cache_expire_at&.> Time.now }
        return info if info

        @info_lock.with_write_lock do
          if @info_cache_expire_at&.> Time.now
            @info_cache = nil
            @info_cache_expire_at = nil
          end
          @info_cache ||= @http_client_v1.get('/v2/bucketInfo', uc_url || get_uc_url(https),
                                              params: { bucket: @bucket_name },
                                              **options).body
          @info_cache_expire_at ||= Time.now + Utils::Duration.new(day: 1).to_i
        end
        @info_cache
      end

      def expire_info!
        @info_lock.with_write_lock do
          @info_cache = nil
          @info_cache_expire_at = nil
        end
        nil
      end

      def get_api_url(api_zone, https)
        https = Config.use_https if https.nil?
        api_zone ||= zone
        api_zone.api_url(https)
      end

      def get_rs_url(rs_zone, https)
        https = Config.use_https if https.nil?
        rs_zone ||= zone
        rs_zone.rs_url(https)
      end

      def get_uc_url(https)
        Common::Zone.uc_url(https)
      end

      def normalize_domains(domains)
        domains = [domains] unless domains.nil? || domains.is_a?(Array)
        domains&.map { |domain| domain.sub(%r{^\w+://}, '') }
      end
    end
  end
end
