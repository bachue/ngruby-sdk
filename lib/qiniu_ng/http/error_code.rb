# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    # HTTP 错误码
    module ErrorCode
      INVALID_ARGUMENT = -4
      INVALID_FILE = -3
      CANCELLED = -2
      NETWORK_ERROR = -1
      UNKNOWN_ERROR = 0
    end
  end
end
