# frozen_string_literal: true

module QiniuNg
  # HTTP 协议相关
  module HTTP
    # 七牛账户错误
    class AccountError < Faraday::Error
    end

    # 客户端错误
    class ClientError < Faraday::ClientError
    end

    # 服务器端错误
    class ServerError < Faraday::ClientError
    end

    # 用户被禁用
    class UserDisabledError < AccountError
    end

    # 用户资源超过上限
    class OutOfLimitError < ServerError
    end

    # 文件上传成功，回调客户服务器失败
    class CallbackFailed < ServerError
    end

    # 七牛服务器功能错误
    class FunctionError < ServerError
    end

    # 服务器端可重试错误
    class ServerRetryableError < ServerError
    end

    # 文件已经被修改
    class FileModified < ClientError
    end

    # 资源没有找到
    class ResourceNotFound < ClientError
    end

    # 资源已经存在
    class ResourceExists < ClientError
    end

    # 流不处于直播中，或该时间点上没有直播数据
    class NoData < ClientError
    end

    # 存储空间过多
    class TooManyBuckets < ClientError
    end

    # 存储空间不存在
    class BucketNotFound < ClientError
    end

    # 不合法的批处理操作标记
    class InvalidMarker < ClientError
    end

    # 不合法的分块上下文
    class InvalidContext < ClientError
    end

    # 部分批处理操作失败
    class PartialOK < ClientError
    end

    # @!visibility private
    class NeedToRetry < Faraday::Error
    end

    # 所有候选地址都已被标记为不可用，没有可用的地址
    class NoURLAvailable < RuntimeError
    end
  end
end
