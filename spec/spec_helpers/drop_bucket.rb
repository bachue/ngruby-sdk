# frozen_string_literal: true

require 'faraday'

module SpecHelpers
  module DropBucket
    def drop!(rs_zone: nil, https: nil, **options)
      clear_all!
      @http_client_v1.post("/drop/#{@bucket_name}", get_rs_url(rs_zone, https), **options)
      nil
    end

    private

    def clear_all!
      batch { |b| files.each { |file| b.delete(file.key) } }
    end
  end

  def self.included(_mod)
    QiniuNg::Storage::Bucket.include(DropBucket)
  end
end
