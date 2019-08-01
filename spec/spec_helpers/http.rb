# frozen_string_literal: true

require 'faraday'
require 'open3'
require 'socket'

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
    r, w = IO.pipe
    pid = spawn(RbConfig.ruby, in: r)
    r.close
    script = <<~CODE
      require 'webrick'
      require 'securerandom'

      server = WEBrick::HTTPServer.new(BindAddress: '127.0.0.1', Port: #{port})
      server.mount_proc '/' do |_, res|
        res['X-Reqid'] = SecureRandom.hex(10)
        res['Etag'] = %(#{etag.inspect}) if #{etag.inspect}
        res['Content-Length'] = '#{size}'
        res.content_type = 'application/octet-stream'
        res.body = File.open('/dev/urandom', 'r')
      end
      trap('INT') { server.shutdown }
      server.start
    CODE
    w.write(script)
    w.close

    loop do
      begin
        TCPSocket.new('127.0.0.1', port).close
        break
      rescue StandardError => _e
        sleep(1)
      end
    end

    pid
  end
end
