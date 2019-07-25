# frozen_string_literal: true

require 'webrick'

module QiniuNg
  module Streaming
    # 七牛直播地址
    #
    # 该类是 String 的子类，因此可以被当成 String 直接使用，不必调用 #to_s 方法。
    class URL < String
      # @!visibility private
      def initialize(protocol, domain, hub, key)
        replace("#{protocol}://#{domain}/#{hub}/#{WEBrick::HTTPUtils.escape(key)}")
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      # 七牛 RTMP 推送流地址（无鉴权地址）
      class RTMPPublishURL < URL
        # @!visibility private
        def initialize(domain, hub, stream_key, auth)
          @domain = domain
          @hub = hub
          @key = stream_key
          @auth = auth
          generate_public_url!
        end

        # 获取带限时鉴权的七牛 RTMP 推送流地址
        # @param [Integer, Hash, QiniuNg::Duration] lifetime 推流地址有效期，与 deadline 参数不要同时使用
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        # @param [Time] deadline 推流地址过期时间，与 lifetime 参数不要同时使用
        # @return [PrivateRTMPPublishURL] 返回带限时鉴权的七牛 RTMP 推送流地址
        def private(lifetime: nil, deadline: nil)
          PrivateRTMPPublishURL.new(self, @auth, lifetime, deadline)
        end

        private

        def generate_public_url!
          replace("rtmp://#{@domain}/#{@hub}/#{WEBrick::HTTPUtils.escape(@key)}")
        end
      end

      # 限时鉴权的七牛 RTMP 推送流地址
      class PrivateRTMPPublishURL < URL
        # @!visibility private
        def initialize(public_url, auth, lifetime, deadline)
          @public_url = public_url
          @auth = auth
          @lifetime = lifetime
          @deadline = deadline
          generate_private_url!
        end

        # 设置下载地址的过期时间
        #
        # @param [Time] deadline 推流地址过期时间
        def deadline=(deadline)
          @deadline = deadline
          @lifetime = nil
          generate_private_url!
        end

        # 设置推流地址的有效期
        #
        # @param [Integer, Hash, QiniuNg::Duration] lifetime 推流地址有效期。
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        def lifetime=(lifetime)
          @lifetime = lifetime
          @deadline = nil
          generate_private_url!
        end

        private

        def generate_private_url!
          if @deadline
            replace(@auth.sign_download_url_with_deadline(@public_url, deadline: @deadline))
          else
            lifetime = @lifetime || Config.default_download_url_lifetime
            replace(@auth.sign_download_url_with_lifetime(@public_url, lifetime: lifetime))
          end
        end
      end
    end
  end
end
