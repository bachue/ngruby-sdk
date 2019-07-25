# frozen_string_literal: true

require 'webrick'
require 'digest/md5'

module QiniuNg
  module Streaming
    # 七牛直播地址
    #
    # 该类是 String 的子类，因此可以被当成 String 直接使用，不必调用 #to_s 方法。
    class URL < String
      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end

      # 七牛直播流播放地址
      class PlayURL < URL
        # @!visibility private
        def initialize(protocol, domain, hub, key)
          @protocol = protocol
          @domain = domain
          @hub = hub
          @key = key
          replace(generate_public_url_without_path + generate_public_url_without_domain)
        end

        # 生成带有时间戳鉴权的播放地址
        #
        # @example
        #   client.hub('<Hub Name>', domain: '<Hub Domain>').stream('<Stream Key>')
        #     .hls_play_url.timestamp_anti_leech(encrypt_key: '<EncryptKey>')
        # @see https://developer.qiniu.io/pili/kb/4161/timestamp-anti-daolian-about-broadcast-domain
        #
        # @param [String] encrypt_key CDN Key
        #   {参考文档}[https://developer.qiniu.com/fusion/kb/1670/timestamp-hotlinking-prevention]
        # @param [Integer, Hash, QiniuNg::Duration] lifetime 下载地址有效期，与 deadline 参数不要同时使用
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        # @param [Time] deadline 下载地址过期时间，与 lifetime 参数不要同时使用
        # @return [TimestampAntiLeechPlayURL] 返回带有时间戳鉴权的播放地址
        def timestamp_anti_leech(encrypt_key:, lifetime: nil, deadline: nil)
          TimestampAntiLeechPlayURL.new(self, encrypt_key, lifetime, deadline)
        end

        private

        def generate_public_url_without_path
          "#{@protocol}://#{@domain}"
        end

        def generate_public_url_without_domain
          "/#{@hub}/#{WEBrick::HTTPUtils.escape(@key)}"
        end
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

        # 设置推流地址的过期时间
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
            replace(@auth.sign_download_url_with_deadline(@public_url, deadline: @deadline, only_path: true))
          else
            lifetime = @lifetime || Config.default_download_url_lifetime
            replace(@auth.sign_download_url_with_lifetime(@public_url, lifetime: lifetime, only_path: true))
          end
        end
      end

      # 七牛直播流的时间戳防盗链播放地址
      class TimestampAntiLeechPlayURL < URL
        # @!visibility private
        def initialize(url, encrypt_key, lifetime, deadline)
          @url = url
          @encrypt_key = encrypt_key
          @lifetime = lifetime
          @deadline = deadline
          generate_timestamp_anti_leech_url!
        end

        # 设置播放地址的过期时间
        #
        # @param [Time] deadline 播放地址过期时间
        def deadline=(deadline)
          @deadline = deadline
          @lifetime = nil
          generate_timestamp_anti_leech_url!
        end

        # 设置播放地址的有效期
        #
        # @param [Integer, Hash, QiniuNg::Duration] lifetime 播放地址有效期。
        #   参数细节可以参考 QiniuNg::Utils::Duration#initialize
        def lifetime=(lifetime)
          @lifetime = lifetime
          @deadline = nil
          generate_timestamp_anti_leech_url!
        end

        private

        def generate_timestamp_anti_leech_url!
          @deadline ||= Time.now + begin
                                     @lifetime ||= Config.default_download_url_lifetime
                                     @lifetime = Utils::Duration.new(@lifetime) if @lifetime.is_a?(Hash)
                                     @lifetime.to_i
                                   end
          deadline_hex = @deadline.to_i.to_s(16).downcase
          url_prefix = @url.send(:generate_public_url_without_path)
          path = @url.send(:generate_public_url_without_domain)
          to_sign_data = "#{@encrypt_key}#{path.encode('UTF-8')}#{deadline_hex}"
          puts to_sign_data
          signed_data = Digest::MD5.hexdigest(to_sign_data).downcase
          if path.include?('?')
            replace("#{url_prefix}#{path}&sign=#{signed_data}&t=#{deadline_hex}")
          else
            replace("#{url_prefix}#{path}?sign=#{signed_data}&t=#{deadline_hex}")
          end
        end
      end
    end
  end
end
