# frozen_string_literal: true

require 'faraday'
require 'webrick'
require 'securerandom'

module SpecHelpers
  def head(url)
    conn = Faraday.new(url) do |c|
      c.request :retry, max: 10, interval: 0.05, interval_randomness: 0.5,
                        backoff_factor: 2, exceptions: QiniuNg::HTTP::RETRYABLE_EXCEPTIONS
      c.adapter :net_http
    end
    conn.head
  end

  def start_server(port:, size:, etag: nil)
    fork do
      server = WEBrick::HTTPServer.new(BindAddress: '127.0.0.1', Port: port)
      server.mount_proc '/' do |_, res|
        res['X-Reqid'] = SecureRandom.hex(10)
        res['Etag'] = %("#{etag}") if etag
        res['Content-Length'] = size.to_s
        res.content_type = 'application/octet-stream'
        res.body = File.open('/dev/urandom', 'r')
      end
      trap('INT') { server.shutdown }
      server.start
    end
  end
end
