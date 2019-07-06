# frozen_string_literal: true

module QiniuNg
  module Common
    # 多区域上传域名
    class Zone
      attr_reader :region
      attr_reader :up_http_urls
      attr_reader :up_https_urls
      attr_reader :io_http_urls
      attr_reader :io_https_urls
      attr_reader :rs_http_url
      attr_reader :rs_https_url
      attr_reader :rsf_http_url
      attr_reader :rsf_https_url
      attr_reader :api_http_url
      attr_reader :api_https_url

      def initialize(
        region:,
        up_http_urls: nil,
        up_https_urls: nil,
        io_http_urls: nil,
        io_https_urls: nil,
        rs_http_url: nil,
        rs_https_url: nil,
        rsf_http_url: nil,
        rsf_https_url: nil,
        api_http_url: nil,
        api_https_url: nil
      )
        @region = region
        @up_http_urls = up_http_urls
        @up_https_urls = up_https_urls
        @io_http_urls = io_http_urls
        @io_https_urls = io_https_urls
        @rs_http_url = rs_http_url || 'http://rs.qiniu.com'
        @rs_https_url = rs_https_url || 'https://rs.qbox.me'
        @rsf_http_url = rsf_http_url || 'http://rsf.qiniu.com'
        @rsf_https_url = rsf_https_url || 'https://rsf.qbox.me'
        @api_http_url = api_http_url || 'http://api.qiniu.com'
        @api_https_url = api_https_url || 'https://api.qiniu.com'
      end

      def up_urls(https = false)
        Utils::Bool.to_bool(https) ? @up_https_urls : @up_http_urls
      end

      def io_urls(https = false)
        Utils::Bool.to_bool(https) ? @up_https_urls : @io_http_urls
      end

      def rs_url(https = false)
        Utils::Bool.to_bool(https) ? @rs_https_url : @rs_http_url
      end

      def rsf_url(https = false)
        Utils::Bool.to_bool(https) ? @rsf_https_url : @rsf_http_url
      end

      def api_url(https = false)
        Utils::Bool.to_bool(https) ? @api_https_url : @api_http_url
      end

      class << self
        def auto
          AutoZone.new
        end

        def huadong
          new(region: 'z0',
              up_http_urls: %w[http://upload.qiniup.com http://up.qiniup.com
                               http://upload.qbox.me http://up.qbox.me],
              up_https_urls: %w[https://upload.qiniup.com https://up.qiniup.com
                                https://upload.qbox.me https://up.qbox.me],
              io_http_urls: %w[http://iovip.qbox.me],
              io_https_urls: %w[https://iovip.qbox.me],
              rs_http_url: 'http://rs.qiniu.com',
              rs_https_url: 'https://rs.qbox.me',
              rsf_http_url: 'http://rsf.qiniu.com',
              rsf_https_url: 'https://rsf.qbox.me',
              api_http_url: 'http://api.qiniu.com',
              api_https_url: 'https://api.qiniu.com').freeze
        end
        alias z0 huadong
        alias zone0 huadong

        def huabei
          new(region: 'z1',
              up_http_urls: %w[http://upload-z1.qiniup.com http://up-z1.qiniup.com
                               http://upload-z1.qbox.me http://up-z1.qbox.me],
              up_https_urls: %w[https://upload-z1.qiniup.com https://up-z1.qiniup.com
                                https://upload-z1.qbox.me https://up-z1.qbox.me],
              io_http_urls: %w[http://iovip-z1.qbox.me],
              io_https_urls: %w[https://iovip-z1.qbox.me],
              rs_http_url: 'http://rs-z1.qiniu.com',
              rs_https_url: 'https://rs-z1.qbox.me',
              rsf_http_url: 'http://rsf-z1.qiniu.com',
              rsf_https_url: 'https://rsf-z1.qbox.me',
              api_http_url: 'http://api-z1.qiniu.com',
              api_https_url: 'https://api-z1.qiniu.com').freeze
        end
        alias z1 huabei
        alias zone1 huabei

        def huanan
          new(region: 'z2',
              up_http_urls: %w[http://upload-z2.qiniup.com http://up-z2.qiniup.com
                               http://upload-z2.qbox.me http://up-z2.qbox.me],
              up_https_urls: %w[https://upload-z2.qiniup.com https://up-z2.qiniup.com
                                https://upload-z2.qbox.me https://up-z2.qbox.me],
              io_http_urls: %w[http://iovip-z2.qbox.me],
              io_https_urls: %w[https://iovip-z2.qbox.me],
              rs_http_url: 'http://rs-z2.qiniu.com',
              rs_https_url: 'https://rs-z2.qbox.me',
              rsf_http_url: 'http://rsf-z2.qiniu.com',
              rsf_https_url: 'https://rsf-z2.qbox.me',
              api_http_url: 'http://api-z2.qiniu.com',
              api_https_url: 'https://api-z2.qiniu.com').freeze
        end
        alias z2 huanan
        alias zone2 huanan

        def beimei
          new(region: 'na0',
              up_http_urls: %w[http://upload-na.qiniup.com http://up-na.qiniup.com
                               http://upload-na.qbox.me http://up-na.qbox.me],
              up_https_urls: %w[https://upload-na.qiniup.com https://up-na.qiniup.com
                                https://upload-na.qbox.me https://up-na.qbox.me],
              io_http_urls: %w[http://iovip-na0.qbox.me],
              io_https_urls: %w[https://iovip-na0.qbox.me],
              rs_http_url: 'http://rs-na0.qiniu.com',
              rs_https_url: 'https://rs-na0.qbox.me',
              rsf_http_url: 'http://rsf-na0.qiniu.com',
              rsf_https_url: 'https://rsf-na0.qbox.me',
              api_http_url: 'http://api-na0.qiniu.com',
              api_https_url: 'https://api-na0.qiniu.com').freeze
        end
        alias na0 beimei
        alias zone_na0 beimei
        alias north_america beimei

        def xinjiapo
          new(region: 'as0',
              up_http_urls: %w[http://upload-as0.qiniup.com http://up-as0.qiniup.com
                               http://upload-as0.qbox.me http://up-as0.qbox.me],
              up_https_urls: %w[https://upload-as0.qiniup.com https://up-as0.qiniup.com
                                https://upload-as0.qbox.me https://up-as0.qbox.me],
              io_http_urls: %w[http://iovip-as0.qbox.me],
              io_https_urls: %w[https://iovip-as0.qbox.me],
              rs_http_url: 'http://rs-as0.qiniu.com',
              rs_https_url: 'https://rs-as0.qbox.me',
              rsf_http_url: 'http://rsf-as0.qiniu.com',
              rsf_https_url: 'https://rsf-as0.qbox.me',
              api_http_url: 'http://api-as0.qiniu.com',
              api_https_url: 'https://api-as0.qiniu.com').freeze
        end
        alias as0 xinjiapo
        alias zone_as0 xinjiapo
        alias singapore xinjiapo
      end

      class << self
        def uc_url(https)
          Utils::Bool.to_bool(https) ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
        end
      end
    end
  end
end
