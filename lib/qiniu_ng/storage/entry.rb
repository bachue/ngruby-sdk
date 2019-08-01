# frozen_string_literal: true

require 'base64'
require 'forwardable'

module QiniuNg
  module Storage
    # 七牛存储空间中的文件项
    #
    # @!attribute [r] bucket
    #   @return [QiniuNg::Storage::Bucket] 存储空间
    # @!attribute [r] key
    #   @return [String] 文件名
    class Entry
      extend Forwardable
      attr_reader :bucket, :key

      # @!visibility private
      def initialize(bucket, key, http_client_v1, http_client_v2, auth)
        @bucket = bucket
        @key = key.freeze
        @entry = Model::Entry.new(bucket: bucket.name, key: key)
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
      end
      def_delegators :@entry, :to_s, :encode

      # 文件是否存在
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Boolean] 文件是否存在
      def exists?(https: nil, **options)
        stat(https: https, **options)
        true
      rescue HTTP::ResourceNotFound
        false
      end

      # 获取文件元信息
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Op::Stat::Result] 返回元信息结果
      def stat(https: nil, **options)
        op = Op::Stat.new(self)
        op.parse(@http_client_v1.get(op, rs_url(https), **options).body)
      end

      # 禁用文件
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def disable!(https: nil, **options)
        @http_client_v1.post(Op::ChangeStatus.new(self, disabled: true), rs_url(https), **options)
        self
      end

      # 启用文件
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def enable!(https: nil, **options)
        @http_client_v1.post(Op::ChangeStatus.new(self, disabled: false), rs_url(https), **options)
        self
      end

      # 设置文件生命周期，该文件将在生命周期结束后被自动删除
      #
      # @param [Integer] days 文件生命周期
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def set_lifetime(days:, https: nil, **options)
        @http_client_v1.post(Op::SetLifetime.new(self, days: days), rs_url(https), **options)
        self
      end

      # 设置文件存储类型为标准存储
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def normal_storage!(https: nil, **options)
        @http_client_v1.post(Op::ChangeType.new(self, type: Model::StorageType.normal), rs_url(https), **options)
        self
      end

      # 设置文件存储类型为低频存储
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def infrequent_storage!(https: nil, **options)
        op = Op::ChangeType.new(self, type: Model::StorageType.infrequent)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      # 设置文件存储类型为低频存储
      #
      # @param [String] mime_type 文件 MIME 类型
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def change_mime_type(mime_type, https: nil, **options)
        @http_client_v1.post(Op::ChangeMIMEType.new(self, mime_type: mime_type), rs_url(https), **options)
        self
      end

      # 设置文件的 HTTP Header 信息
      #
      # @param [Hash] meta 文件的 HTTP Header 信息
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def change_meta(meta, https: nil, **options)
        @http_client_v1.post(Op::ChangeMeta.new(self, meta: meta), rs_url(https), **options)
        self
      end

      # 重命名文件
      #
      # @param [String] key 目标文件名
      # @param [Boolean] force 是否覆盖，当目标文件名已经存在时
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def rename_to(key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: @bucket.name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      # 移动文件
      #
      # @param [String] bucket_name 目标存储空间名称
      # @param [String] key 目标文件名
      # @param [Boolean] force 是否覆盖，当目标文件名已经存在时
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def move_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Move.new(self, bucket: bucket_name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      # 复制文件
      #
      # @param [String] bucket_name 目标存储空间名称
      # @param [String] key 目标文件名
      # @param [Boolean] force 是否覆盖，当目标文件名已经存在时
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def copy_to(bucket_name, key, force: false, https: nil, **options)
        op = Op::Copy.new(self, bucket: bucket_name, key: key, force: force)
        @http_client_v1.post(op, rs_url(https), **options)
        self
      end

      # 删除文件
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def delete(https: nil, **options)
        @http_client_v1.post(Op::Delete.new(self), rs_url(https), **options)
        self
      end

      # 尝试删除文件，如果文件不存在也不会抛出异常
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def try_delete(https: nil, **options)
        delete(https: https, **options)
      rescue HTTP::ResourceNotFound
        # do nothing
        self
      end

      # 从镜像存储中预取文件
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Entry] 返回上下文
      def prefetch(https: nil, **options)
        @http_client_v1.post("/prefetch/#{encode}", io_urls(https), **options)
        self
      end

      # 从指定 URL 中抓取文件
      #
      # @param [String] url 从指定的 URL 抓取文件
      # @param [Boolean] async 是否使用异步抓取（推荐尽可能使用异步抓取，将会有效提高抓取效率）
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Model::FetchedEntry, QiniuNg::Storage::Model::AsyncFetchJob] 返回抓取结果或异步抓取任务
      def fetch_from(url, async: false, https: nil, **options)
        return async_fetch_from(url, https: https, **options) if async

        encoded_url = Base64.urlsafe_encode64(url)
        body = @http_client_v1.post("/fetch/#{encoded_url}/to/#{encode}", io_urls(https), **options).body
        Model::FetchedEntry.new(self, hash: body['hash'], mime_type: body['mimeType'], file_size: body['fsize'])
      end

      # 从指定 URL 中异步抓取文件
      #
      # @example
      #   job = client.bucket('<Bucket Name>').entry('key').async_fetch_from('<URL>', md5: '<Resource MD5>')
      #   expect(job.done?).to be false
      #   saved_async_fetch_job_id = job.id
      #
      #   job = bucket.query_async_fetch_result(saved_async_fetch_job_id)
      #   expect(job.done?).to be true
      #
      # @param [String] url 从指定的 URL 抓取文件
      # @param [String] md5 目标文件的 MD5 值，由云存储校验抓取结果是否正确
      # @param [String] callback_url 抓取完成后回调业务服务器的 URL。
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-url]
      # @param [String] callback_host 抓取完成后的回调 HOST
      # @param [String] callback_body 抓取完成后回调请求的内容，如果 callback_url 不为空则必须指定。
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-body]
      # @param [String] callback_body_type 抓取完成后回调请求的内容类型，默认为 application/x-www-form-urlencoded。
      #   {参考文档}[https://developer.qiniu.com/kodo/manual/1206/put-policy#put-policy-callback-body-type]
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Model::AsyncFetchJob] 返回异步抓取任务
      def async_fetch_from(url, md5: nil, https: nil, callback_url: nil, callback_host: nil,
                           callback_body: nil, callback_body_type: nil, **options)
        req_body = {
          url: url, bucket: @bucket.name, key: @key, md5: md5, callbackurl: callback_url,
          callbackhost: callback_host, callbackbody: callback_body, callbackbodytype: callback_body_type
        }.reject { |_, v| v.nil? }
        resp_body = @http_client_v2.post('/sisyphus/fetch', api_url(https),
                                         headers: { content_type: 'application/json' },
                                         body: Config.default_json_marshaler.call(req_body),
                                         **options).body
        Model::AsyncFetchJob.new(@bucket, @http_client_v2, resp_body['id'])
      end

      # 为公开空间生成下载地址
      #
      # @example
      #   client.bucket('<Bucket Name>').entry('<key>').public_url
      #
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Array<String>, String] domains 下载域名列表。默认将使用存储空间绑定的下载域名列表
      # @param [String] filename 下载到本地后的文件名，该参数仅对由浏览器打开的地址有效
      # @param [String] fop 数据处理参数。{参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] style 数据处理样式。{参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [PublicURL, nil] 返回文件的下载地址，如果没有提供域名且存储空间在七牛没有绑定任何域名将返回 nil
      def public_url(api_zone: nil, uc_url: nil, domains: nil, https: nil,
                     filename: nil, fop: nil, style: nil, **options)
        if domains.nil? || domains.empty?
          domains = @bucket.domains(api_zone: api_zone, https: https, **options).reverse
        elsif !domains.is_a?(Array)
          domains = [domains].compact
        end

        return if domains.empty?

        PublicURL.new(domains, @key, @auth,
                      style_separator: @bucket.style_separator(uc_url: uc_url, https: https, **options),
                      filename: filename, fop: fop, style: style, https: https)
      end

      # 根据空间情况及参数生成合适的下载地址
      #
      # 如果给出了 encrypt_key 参数，则生成时间戳防盗链下载地址。
      # 否则，当给出了 deadline 或 lifetime 参数，或当前空间为私有空间，则给出私有空间的下载地址。
      # 否则，给出公开空间的下载地址。
      #
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Array<String>, String] domains 下载域名列表。默认将使用存储空间绑定的下载域名列表
      # @param [String] filename 下载到本地后的文件名，该参数仅对由浏览器打开的地址有效
      # @param [String] fop 数据处理参数。{参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] style 数据处理样式。{参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期，与 deadline 参数不要同时使用
      #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
      # @param [Time] deadline 下载地址过期时间，与 lifetime 参数不要同时使用
      # @return [PublicURL, PrivateURL, TimestampAntiLeechURL, nil]
      #   返回文件的下载地址，将会自动根据配置返回正确的下载地址。如果没有提供域名且存储空间在七牛没有绑定任何域名将返回 nil
      def download_url(api_zone: nil, uc_url: nil, domains: nil, https: nil,
                       filename: nil, fop: nil, style: nil,
                       lifetime: nil, deadline: nil, encrypt_key: nil, **options)
        url = public_url(api_zone: api_zone, uc_url: uc_url, domains: domains, https: https,
                         filename: filename, fop: fop, style: style, **options)
        if encrypt_key
          url = url.timestamp_anti_leech(encrypt_key: encrypt_key, lifetime: lifetime, deadline: deadline)
        elsif lifetime || deadline || @bucket.private?
          url = url.private(lifetime: lifetime, deadline: deadline)
        end
        url
      end

      # 生成用于上传该文件的上传凭证
      #
      # @example
      #   token = entry.upload_token do |policy|
      #             policy.set_token_lifetime(day: 1) }
      #           end
      #   entry.bucket.upload(filepath: '/path/to/file', upload_token: token)
      #
      # @yield [policy] 在生成上传凭证前对生成的上传策略进行修改
      # @yieldparam policy [QiniuNg::Storage::Model::UploadPolicy] 生成的上传策略
      # @return [QiniuNg::Storage::UploadToken] 返回上传凭证
      def upload_token
        policy = Model::UploadPolicy.new(bucket: @bucket.name, key: @key)
        yield policy if block_given?
        UploadToken.from_policy(policy, @auth)
      end

      # 对该文件调用持久化数据处理
      #
      # @param [String] fop 数据处理参数。{参考文档}[https://developer.qiniu.com/dora/manual/1204/processing-mechanism]
      # @param [String] pipeline 数据处理队列。
      #   {参考文档}[https://developer.qiniu.com/dora/kb/3853/how-to-create-audio-and-video-processing-private-queues]
      # @param [String] notify_url 处理结果通知接收 URL。
      #   {参考文档}[https://developer.qiniu.com/dora/manual/1291/persistent-data-processing-pfop#pfop-notification]
      # @param [Boolean] force 强制执行数据处理，当服务端发现 fops 指定的数据处理结果已经存在，那就认为已经处理成功，避免重复处理浪费资源
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Processing::PersistentID] 返回持久化处理 ID
      def pfop(fop, pipeline:, notify_url: nil, force: nil, api_zone: nil, https: nil, **options)
        Processing::Manager.new(@http_client_v1).pfop(self, fop, pipeline: pipeline, notify_url: notify_url,
                                                                 force: force, api_zone: api_zone,
                                                                 https: https, **options)
      end

      # 获取文件的 MD5
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Array<String>, String] domains 下载域名列表。默认将使用存储空间绑定的下载域名列表
      def md5(api_zone: nil, uc_url: nil, domains: nil, https: nil, **options)
        qhash(:md5, api_zone: api_zone, uc_url: uc_url, domains: domains, https: https, **options)
      end

      # 获取文件的 SHA1
      # @param [QiniuNg::Zone] api_zone API 所在区域，一般无需填写
      # @param [String] uc_url UC 所在服务器地址，一般无需填写
      # @param [Array<String>, String] domains 下载域名列表。默认将使用存储空间绑定的下载域名列表
      def sha1(api_zone: nil, uc_url: nil, domains: nil, https: nil, **options)
        qhash(:sha1, api_zone: api_zone, uc_url: uc_url, domains: domains, https: https, **options)
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} bucket.name=#{@bucket.name.inspect} @key=#{@key.inspect}>"
      end

      private

      def qhash(algorithm, api_zone: nil, uc_url: nil, domains: nil, https: nil, **options)
        url = download_url(fop: "qhash/#{algorithm}", api_zone: api_zone, uc_url: uc_url,
                           domains: domains, https: https, **options)
        Config.default_json_unmarshaler.call(url.reader(disable_checksum: true).read)['hash']
      end

      def rs_url(https)
        https = Config.use_https if https.nil?
        @bucket.zone.rs_url(https)
      end

      def api_url(https)
        https = Config.use_https if https.nil?
        @bucket.zone.api_url(https)
      end

      def io_urls(https)
        https = Config.use_https if https.nil?
        @bucket.zone.io_urls(https).dup
      end
    end
  end
end
