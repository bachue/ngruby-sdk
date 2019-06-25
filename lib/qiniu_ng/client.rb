# frozen_string_literal: true

require 'faraday'
require 'forwardable'

module QiniuNg
  # 七牛 SDK 客户端
  class Client
    extend Forwardable

    def initialize(access_key:, secret_key:)
      @auth = Utils::Auth.new(access_key: access_key, secret_key: secret_key)
      @http_client_with_auth_v1 = HTTP.client(auth: @auth, auth_version: 1)
      @bucket_manager = Storage::BucketManager.new(@http_client_with_auth_v1, @auth)
    end

    def_delegators :@bucket_manager, :bucket_names, :create_bucket, :drop_bucket, :delete_bucket, :bucket

    def batch
      BatchOperation.new(nil, @http_client, @auth)
    end
  end
end
