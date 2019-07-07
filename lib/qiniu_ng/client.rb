# frozen_string_literal: true

require 'faraday'
require 'forwardable'
require 'qiniu_ng/storage/bucket_manager'
require 'qiniu_ng/cdn/manager'

module QiniuNg
  # 七牛 SDK 客户端
  class Client
    extend Forwardable

    def initialize(auth)
      @auth = auth
      @http_client_with_auth_v1 = HTTP.client(auth: auth, auth_version: 1)
      @http_client_with_auth_v2 = HTTP.client(auth: auth, auth_version: 2)
      @bucket_manager = Storage::BucketManager.new(@http_client_with_auth_v1, @http_client_with_auth_v2, auth)
      @cdn_manager = CDN::Manager.new(@http_client_with_auth_v2)
    end

    def_delegators :@bucket_manager, *Storage::BucketManager.public_instance_methods(false)
    def_delegators :@cdn_manager, *CDN::Manager.public_instance_methods(false)

    def batch
      gatchOperation.new(nil, @http_client, @auth)
    end
  end
end
