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

    def initialize(auth, domains_manager: nil)
      @domains_manager = domains_manager || HTTP::DomainsManager.new
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

    def batch(zone:, raise_if_partial_ok: false, **options)
      op = Storage::BatchOperations.new(nil, @http_client_with_auth_v1, @http_client_with_auth_v2,
                                        @auth, raise_if_partial_ok)
      return op unless block_given?

      yield op
      op.do(zone: zone, **options)
    end

    def batch!(zone:, **options, &block)
      batch(zone: zone, raise_if_partial_ok: true, **options, &block)
    end
  end
end
