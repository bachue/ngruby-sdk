# frozen_string_literal: true

require 'faraday'
require 'forwardable'
require 'qiniu_ng/storage/bucket_manager'
require 'qiniu_ng/processing/operation_manager'
require 'qiniu_ng/cdn/manager'

module QiniuNg
  # 七牛 SDK 客户端
  class Client
    extend Forwardable

    # @!visibility private
    def initialize(auth, domains_manager: Config.default_domains_manager)
      @domains_manager = domains_manager
      @auth = auth
      @http_client_with_auth_v1 = HTTP.client(auth: auth, auth_version: 1, domains_manager: @domains_manager)
      @http_client_with_auth_v2 = HTTP.client(auth: auth, auth_version: 2, domains_manager: @domains_manager)
      @bucket_manager = Storage::BucketManager.new(@http_client_with_auth_v1, @http_client_with_auth_v2, auth)
      @operation_manager = Processing::OperationManager.new(@http_client_with_auth_v1)
      @cdn_manager = CDN::Manager.new(@http_client_with_auth_v2)
    end

    def_delegators :@bucket_manager, *Storage::BucketManager.public_instance_methods(false)
    def_delegators :@operation_manager, *Processing::OperationManager.public_instance_methods(false)
    def_delegators :@cdn_manager, *CDN::Manager.public_instance_methods(false)

    # 发送文件批处理操作
    # @example
    #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
    #   bucket1, bucket2, bucket3 = client.bucket('bucket1'), client.bucket('bucket2'), client.bucket('bucket3')
    #   results = client.batch(zone: QiniuNg::Zone.huadong) do |batch|
    #               batch.stat('key1', bucket: bucket1)
    #               batch.stat('key2', bucket: bucket2)
    #               batch.stat('key3', bucket: bucket3)
    #             end
    #
    # @param [QiniuNg::Zone] zone 批处理操作所发生的{区域}[https://developer.qiniu.com/kodo/manual/1671/region-endpoint]
    # @param [Bool] raise_if_partial_ok 如果部分操作发生错误，是否会抛出异常
    # @param [Bool] https 批处理操作是否使用 HTTPS 协议发送
    # @param [Hash] options 额外的 Faraday 参数
    # @yield [batch] 作为批处理操作的上下文
    # @yieldparam batch [QiniuNg::Storage::BatchOperations] 批处理操作的上下文
    # @return [QiniuNg::Storage::BatchOperations::Results] 批处理操作结果
    def batch(zone:, raise_if_partial_ok: false, https: nil, **options)
      op = Storage::BatchOperations.new(nil, @http_client_with_auth_v1, @http_client_with_auth_v2,
                                        @auth, raise_if_partial_ok)
      return op unless block_given?

      yield op
      op.do(zone: zone, https: https, **options)
    end

    # 发送文件批处理操作，如果部分操作发生异常，将会抛出 QiniuNg::HTTP::PartialOK 异常
    #
    # @example
    #   client = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
    #   bucket1, bucket2, bucket3 = client.bucket('bucket1'), client.bucket('bucket2'), client.bucket('bucket3')
    #   results = client.batch!(zone: QiniuNg::Zone.huadong) do |batch|
    #               batch.stat('key1', bucket: bucket1)
    #               batch.stat('key2', bucket: bucket2)
    #               batch.stat('key3', bucket: bucket3)
    #             end
    #
    # @param [QiniuNg::Zone] zone 批处理操作所发生的{区域}[https://developer.qiniu.com/kodo/manual/1671/region-endpoint]
    # @param [Bool] https 批处理操作是否使用 HTTPS 协议发送
    # @param [Hash] options 额外的 Faraday 参数
    # @raise [QiniuNg::HTTP::PartialOK] 如果部分操作发生异常
    # @yield [batch] 作为批处理操作的上下文
    # @yieldparam batch [QiniuNg::Storage::BatchOperations] 批处理操作的上下文
    # @return [QiniuNg::Storage::BatchOperations::Results] 批处理操作结果
    def batch!(zone:, https: nil, **options, &block)
      batch(zone: zone, raise_if_partial_ok: true, https: https, **options, &block)
    end
  end
end
