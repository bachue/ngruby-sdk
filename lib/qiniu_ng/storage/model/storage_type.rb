# frozen_string_literal: true

require 'ruby-enum'

module QiniuNg
  module Storage
    module Model
      # 存储类型（normal: 普通存储，infrequent: 低频存储）
      class StorageType
        include Ruby::Enum

        define :normal, 0
        define :infrequent, 1
      end
    end
  end
end
