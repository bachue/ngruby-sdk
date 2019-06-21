# frozen_string_literal: true

require 'digest'

module QiniuNg
  module Utils
    # 七牛认证相关
    class Etag
      class << self
        def from_data(data)
          from_io StringIO.new(data)
        end

        def from_file_path(path)
          File.open(path, 'rb') { |io| from_file(io) }
        end

        def from_io(io)
          io.binmode

          sha1s = []
          until io.eof?
            block_data = io.read(QiniuNg::BLOCK_SIZE)
            sha1s << sha1(block_data)
          end
          encode_sha1s(sha1s)
        end
        alias from_file from_io

        private

        def encode_sha1s(sha1s)
          case sha1s.size
          when 0
            'Fto5o-5ea0sNMlW_75VgGJCv2AcJ'
          when 1
            Base64.urlsafe_encode64(0x16.chr + sha1s.first)
          else
            Base64.urlsafe_encode64(0x96.chr + sha1(sha1s.join))
          end
        end

        def sha1(data)
          Digest::SHA1.digest(data)
        end
      end
    end
  end
end
