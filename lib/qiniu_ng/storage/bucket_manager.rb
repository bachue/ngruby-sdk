# frozen_string_literal: true

require 'base64'

module QiniuNg
  module Storage
    # 七牛存储空间管理
    #
    # 该类所有方法都已被委托给 QiniuNg::Client 直接调用
    class BucketManager
      # @!visibility private
      def initialize(http_client_v1, http_client_v2, auth)
        @http_client_v1 = http_client_v1
        @http_client_v2 = http_client_v2
        @auth = auth
      end

      # 获取所有存储空间名称
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket_names = client.bucket_names
      #
      # @param [QiniuNg::Zone] rs_zone RS 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [Array<String>] 存储空间名称列表
      def bucket_names(rs_zone: nil, https: nil, **options)
        @http_client_v1.get('/buckets', rs_url(rs_zone, https), **options).body
      end

      # 创建一个新的存储空间
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   new_bucket = client.create_bucket('<New Bucket Name>', zone: :z2)
      #
      # @param [String] bucket_name 新建的存储空间名称
      # @param [QiniuNg::Zone, Symbol] zone 新建的 Bucket 所在的区域，
      #   可以用{代号}[https://developer.qiniu.com/kodo/manual/1671/region-endpoint]表示，默认为华东区
      # @param [QiniuNg::Zone] rs_zone RS 所在区域，一般无需填写
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @param [Hash] options 额外的 Faraday 参数
      # @return [QiniuNg::Storage::Bucket] 存储空间实例
      def create_bucket(bucket_name, zone: :z0, rs_zone: nil, https: nil, **options)
        region = zone.is_a?(Common::Zone) ? zone.region || :z0 : zone
        encoded_bucket_name = Base64.urlsafe_encode64(bucket_name)
        @http_client_v1.post("/mkbucketv2/#{encoded_bucket_name}/region/#{region}", rs_url(rs_zone, https), **options)
        bucket(bucket_name)
      end

      # 获取一个存储空间实例
      #
      # @example
      #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
      #   bucket = client.bucket('<Bucket Name>')
      #   bucket_on_huabei = client.bucket('<Bucket Name>', zone: QiniuNg::Zone.huabei)
      #
      # @param [String] bucket_name 获取的存储空间名称
      # @param [QiniuNg::Zone] zone 存储空间所在的区域，默认将会自动判断
      # @param [Array<String>, String] domains 存储空间所用的下载域名，默认将会使用绑定在存储空间上的下载域名
      # @return [QiniuNg::Storage::Bucket] 存储空间实例
      def bucket(bucket_name, zone: nil, domains: nil)
        Bucket.new(bucket_name, zone, @http_client_v1, @http_client_v2, @auth, domains)
      end

      private

      def rs_url(rs_zone, https)
        https = Config.use_https if https.nil?
        rs_zone ||= Common::Zone.huadong
        rs_zone.rs_url(https)
      end
    end
  end
end
