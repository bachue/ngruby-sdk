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
        # 初始化文件记录器
        #
        # @param [Pathname] dir 文件记录所在目录
        def initialize(dir = Config.default_file_recorder_path)
          FileUtils.mkdir_p(dir)
          @dir = Pathname.new(dir)
        end

        # 设置记录
        #
        # @param [String] key 记录名
        # @param [String] data 记录内容
        def set(key, data)
          File.binwrite(@dir.join(key), data)
        end

        # 获取记录
        #
        # @param [String] key 记录名
        # @return [String] 记录内容
        def get(key)
          path = @dir.join(key)
          File.open(path, 'rb') do |file|
            return File.unlink(path) if out_of_date?(file)

            file.read
          end
        rescue Errno::ENOENT
          # Do nothing
        end

        # 删除记录
        #
        # @param [String] key 记录名
        def del(key)
          File.unlink(@dir.join(key))
          nil
        rescue Errno::ENOENT
          # Do nothing
        end

        class << self
          # 获得记录名
          #
          # @param [String] bucket 存储空间名称
          # @param [String] key 文件名
          # @param [File] file 上传的文件
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
