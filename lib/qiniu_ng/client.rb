# frozen_string_literal: true

require 'faraday'
require 'forwardable'
require 'qiniu_ng/storage/bucket_manager'

module QiniuNg
  # 七牛 SDK 客户端
  class Client
    extend Forwardable

    def initialize(access_key:, secret_key:)
      @auth = Utils::Auth.new(access_key: access_key, secret_key: secret_key)
      @http_client_with_auth_v1 = HTTP.client(auth: @auth, auth_version: 1)
      @http_client_with_auth_v2 = HTTP.client(auth: @auth, auth_version: 2)
      @bucket_manager = Storage::BucketManager.new(@http_client_with_auth_v1, @http_client_with_auth_v2, @auth)
    end

    def_delegators :@bucket_manager, *QiniuNg::Storage::BucketManager.public_instance_methods(false)

    def batch
      BatchOperation.new(nil, @http_client, @auth)
    end
  end
end
