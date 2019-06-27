# frozen_string_literal: true

require 'faraday'

module SpecHelpers
  def head(url)
    conn = Faraday.new(url) do |c|
      c.request :retry, max: 5, interval: 0.05, interval_randomness: 0.5, backoff_factor: 2
      c.adapter :net_http_persistent
    end
    conn.head
  end

  def get(url)
    conn = Faraday.new(url) do |c|
      c.request :retry, max: 5, interval: 0.05, interval_randomness: 0.5, backoff_factor: 2
      c.adapter :net_http_persistent
    end
    conn.head
  end
end
