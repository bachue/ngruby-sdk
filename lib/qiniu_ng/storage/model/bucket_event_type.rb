# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛存储空间事件类型
      module BucketEventType
        PUT = 'put'
        MKFILE = 'mkfile'
        DELETE = 'delete'
        COPY = 'copy'
        MOVE = 'move'
        APPEND = 'append'
        DISABLE = 'disable'
        ENABLE = 'enable'
        DELETE_MARKER_CREATE = 'deleteMarkerCreate'
      end
    end
  end
end
