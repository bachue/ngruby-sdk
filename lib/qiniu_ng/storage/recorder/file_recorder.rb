# frozen_string_literal: true

require 'base64'
require 'digest/sha1'
require 'duration'
require 'fileutils'
require 'pathname'

module QiniuNg
  module Storage
    # 记录器模块
    module Recorder
      # 文件记录器
      class FileRecorder
        def initialize(dir = Config.default_file_recorder_path)
          FileUtils.mkdir_p(dir)
          @dir = Pathname.new(dir)
          @mutex = Mutex.new
        end

        def set(key, data)
          @mutex.synchronize do
            File.binwrite(@dir.join(key), data)
          end
        end

        def get(key)
          path = @dir.join(key)
          File.open(path, 'rb') do |file|
            return File.unlink(path) if out_of_date?(file)

            file.read
          end
        rescue Errno::ENOENT
          # Do nothing
        end

        def del(key)
          File.unlink(@dir.join(key))
        rescue Errno::ENOENT
          # Do nothing
        end

        class << self
          def recorder_key_for_file(bucket: nil, key: nil, file: nil)
            base64_key = Base64.urlsafe_encode64(key) if key
            path = File.absolute_path(file.path) if file
            mtime = file.mtime.to_i.to_s if file
            hash([bucket, base64_key, mtime, path].compact.join('_._'))
          end

          private

          def hash(data)
            Digest::SHA1.hexdigest(data)
          end
        end

        private

        def out_of_date?(file)
          file.mtime + Duration.new(days: 5).to_i < Time.now
        end
      end
    end
  end
end
