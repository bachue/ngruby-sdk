# frozen_string_literal: true

module QiniuNg
  # 通用功能模块
  module Common
    # @!visibility private
    module Constant
      BLOCK_SIZE = 1 << 22
    end

    include Constant
  end
end
