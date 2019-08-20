# frozen_string_literal: true

require 'faraday'

module SpecHelpers
  module ClearBucket
    def clear_all!
      batch { |b| files.each { |file| b.delete(file.key) } }
    end
  end

  def self.included(_mod)
    QiniuNg::Storage::Bucket.include(ClearBucket)
  end
end
