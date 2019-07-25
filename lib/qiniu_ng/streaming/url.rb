# frozen_string_literal: true

require 'webrick'

module QiniuNg
  module Streaming
    class URL < String
      # @!visibility private
      def initialize(protocol, domain, hub, key)
        replace("#{protocol}://#{domain}/#{hub}/#{WEBrick::HTTPUtils.escape(key)}")
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      # 七牛 RTMP 推送流地址
      class RTMPPublishURL < URL
        def initialize(domain, hub, stream_key, auth)
          @domain = domain
          @hub = hub
          @key = stream_key
          @auth = auth
          generate_public_url!
        end

        def private(lifetime: nil, deadline: nil)
          PrivateRTMPPublishURL.new(self, @auth, lifetime, deadline)
        end

        private

        def generate_public_url!
          replace("rtmp://#{@domain}/#{@hub}/#{WEBrick::HTTPUtils.escape(@key)}")
        end
      end

      class PrivateRTMPPublishURL < URL
        def initialize(public_url, auth, lifetime, deadline)
          @public_url = public_url
          @auth = auth
          @lifetime = lifetime
          @deadline = deadline
          generate_private_url!
        end

        # 设置下载地址的过期时间
        #
        # @param [Time] deadline 下载地址过期时间
        def deadline=(deadline)
          @deadline = deadline
          @lifetime = nil
          generate_private_url!
        end

        # 设置下载地址的有效期
        #
        # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期。
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
