# frozen_string_literal: true

require 'faraday'

module SpecHelpers
  module DropBucket
    def drop_bucket(bucket_name, rs_zone: nil, https: nil, **options)
      @http_client_v1.post("/drop/#{bucket_name}", rs_url(rs_zone, https), **options)
      nil
    end
  end

  module ClientDropBucket
    def drop_bucket(bucket_name, rs_zone: nil, https: nil, **options)
      @bucket_manager.drop_bucket(bucket_name, rs_zone: rs_zone, https: https, **options)
    end
  end

  def self.included(_mod)
    QiniuNg::Storage::BucketManager.include(DropBucket)
    QiniuNg::Client.include(ClientDropBucket)
  end
end
