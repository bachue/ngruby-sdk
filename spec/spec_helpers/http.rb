# frozen_string_literal: true

require 'faraday'

module SpecHelpers
  def head(url)
    conn = Faraday.new(url) do |c|
      c.request :retry, max: 10, interval: 0.05, interval_randomness: 0.5,
                        backoff_factor: 2, exceptions: QiniuNg::HTTP::RETRYABLE_EXCEPTIONS
      c.adapter :net_http
    end
    conn.head
  end
end
