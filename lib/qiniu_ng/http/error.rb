# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    # HTTP 错误码
    class Error < Faraday::Error
    end

    class AccountError < Faraday::Error
    end

    class ClientError < Faraday::ClientError
    end

    class ServerError < Faraday::ClientError
    end

    class PartialOKError < Error
    end

    class UserDisabledError < AccountError
    end

    class OutOfLimitError < ServerError
    end

    class CallbackFailed < ServerError
    end

    class FunctionError < ServerError
    end

    class FileModified < ClientError
    end

    class ResourceNotFound < ClientError
    end

    class ResourceExists < ClientError
    end

    class TooManyBuckets < ClientError
    end

    class BucketNotFound < ClientError
    end

    class InvalidMarker < ClientError
    end

    class InvalidContext < ClientError
    end
  end
end
