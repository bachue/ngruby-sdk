# frozen_string_literal: true

require 'faraday'

module QiniuNg
  # 七牛 SDK 客户端
  class Client
    attr_reader :access_key
    attr_reader :secret_key

    def initialize(
      access_key:,
      secret_key:,
      faraday: nil
    )
      @access_key = access_key
      @secret_key = secret_key
      @faraday_connection = faraday || HTTP.client
    end
  end
end
