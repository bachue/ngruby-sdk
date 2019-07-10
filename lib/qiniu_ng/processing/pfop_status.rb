# frozen_string_literal: true

require 'ruby-enum'

module QiniuNg
  module Processing
    # 七牛文件处理持久化状态
    class PfopStatus
      include Ruby::Enum

      define :ok, 0
      define :pending, 1
      define :processing, 2
      define :failed, 3
      define :callback_failed, 4
    end
  end
end
