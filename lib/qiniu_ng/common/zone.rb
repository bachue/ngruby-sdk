# frozen_string_literal: true

module QiniuNg
  module Common
    # 多区域上传域名
    # @!attribute [r] region_id
    #   @return [String] 区域代号
    # @!attribute [r] up_http_urls
    #   @return [Array<String>] UP 地址集合（HTTP 协议）
    # @!attribute [r] up_https_urls
    #   @return [Array<String>] UP 地址集合（HTTPS 协议）
    # @!attribute [r] io_http_urls
    #   @return [Array<String>] IO 地址集合（HTTP 协议）
    # @!attribute [r] io_https_urls
    #   @return [Array<String>] IO 地址集合（HTTPS 协议）
    # @!attribute [r] rs_http_url
    #   @return [String] RS 地址（HTTP 协议）
    # @!attribute [r] rs_https_url
    #   @return [String] RS 地址（HTTPS 协议）
    # @!attribute [r] rsf_http_url
    #   @return [String] RSF 地址（HTTP 协议）
    # @!attribute [r] rsf_https_url
    #   @return [String] RSF 地址（HTTPS 协议）
    # @!attribute [r] api_http_url
    #   @return [String] API 地址（HTTP 协议）
    # @!attribute [r] api_https_url
    #   @return [String] API 地址（HTTPS 协议）
    class Zone
      attr_reader :region_id
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

      # 初始化一个区域
      # @param [String] region_id 区域代号
      # @param [String, Array<String>] up_http_urls UP 地址集合（HTTP 协议）
      # @param [String, Array<String>] up_https_urls UP 地址集合（HTTPS 协议）
      # @param [String, Array<String>] io_http_urls UP 地址集合（HTTP 协议）
      # @param [String, Array<String>] io_https_urls UP 地址集合（HTTPS 协议）
      # @param [String] rs_http_url RS 地址（HTTP 协议）
      # @param [String] rs_https_url RS 地址（HTTPS 协议）
      # @param [String] rsf_http_url RSF 地址（HTTP 协议）
      # @param [String] rsf_https_url RSF 地址（HTTPS 协议）
      # @param [String] api_http_url API 地址（HTTP 协议）
      # @param [String] api_https_url API 地址（HTTPS 协议）
      def initialize(
        region_id:,
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
        @region_id = region_id
        @up_http_urls = normalize_array(up_http_urls)
        @up_https_urls = normalize_array(up_https_urls)
        @io_http_urls = normalize_array(io_http_urls)
        @io_https_urls = normalize_array(io_https_urls)
        @rs_http_url = rs_http_url || 'http://rs.qiniu.com'
        @rs_https_url = rs_https_url || 'https://rs.qbox.me'
        @rsf_http_url = rsf_http_url || 'http://rsf.qiniu.com'
        @rsf_https_url = rsf_https_url || 'https://rsf.qbox.me'
        @api_http_url = api_http_url || 'http://api.qiniu.com'
        @api_https_url = api_https_url || 'https://api.qiniu.com'
      end

      # UP 地址集合
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [Array<String>] 返回 UP 地址集合
      def up_urls(https = false)
        Utils::Bool.to_bool(https) ? @up_https_urls : @up_http_urls
      end

      # IO 地址集合
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [Array<String>] 返回 IO 地址集合
      def io_urls(https = false)
        Utils::Bool.to_bool(https) ? @up_https_urls : @io_http_urls
      end

      # RS 地址
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [String] 返回 RS 地址
      def rs_url(https = false)
        Utils::Bool.to_bool(https) ? @rs_https_url : @rs_http_url
      end

      # RSF 地址
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [String] 返回 RSF 地址
      def rsf_url(https = false)
        Utils::Bool.to_bool(https) ? @rsf_https_url : @rsf_http_url
      end

      # API 地址
      #
      # @param [Boolean] https 是否使用 HTTPS 协议
      # @return [String] 返回 API 地址
      def api_url(https = false)
        Utils::Bool.to_bool(https) ? @api_https_url : @api_http_url
      end

      class << self
        # 自动区域判断
        # @example
        #   zone = QiniuNg::Zone.auto.query(access_key: '<Qiniu AccessKey>', bucket: '<Bucket Name>')
        #
        # @return [QiniuNg::AutoZone] 返回自动域名判断类
        def auto
          AutoZone.new
        end

        # 默认华东区域
        # @example
        #   zone = QiniuNg::Zone.huadong
        #
        # @return [QiniuNg::Zone] 返回华东区域
        def huadong
          new(region_id: 'z0',
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

        # 默认华北区域
        # @example
        #   zone = QiniuNg::Zone.huabei
        #
        # @return [QiniuNg::Zone] 返回华北区域
        def huabei
          new(region_id: 'z1',
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

        # 默认华南区域
        # @example
        #   zone = QiniuNg::Zone.huanan
        #
        # @return [QiniuNg::Zone] 返回华南区域
        def huanan
          new(region_id: 'z2',
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

        # 默认北美区域
        # @example
        #   zone = QiniuNg::Zone.north_america
        #
        # @return [QiniuNg::Zone] 返回北美区域
        def north_america
          new(region_id: 'na0',
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
        alias na0 north_america
        alias zone_na0 north_america
        alias beimei north_america

        # 默认新加坡区域
        # @example
        #   zone = QiniuNg::Zone.singapore
        #
        # @return [QiniuNg::Zone] 返回新加坡区域
        def singapore
          new(region_id: 'as0',
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
        alias as0 singapore
        alias zone_as0 singapore
        alias xinjiapo singapore
      end

      class << self
        # @!visibility private
        def uc_url(https)
          Utils::Bool.to_bool(https) ? 'https://uc.qbox.me' : 'http://uc.qbox.me'
        end

        # @!visibility private
        def fusion_url(https)
          Utils::Bool.to_bool(https) ? 'https://fusion.qiniuapi.com' : 'http://fusion.qiniuapi.com'
        end

        # @!visibility private
        def pili_url(https)
          Utils::Bool.to_bool(https) ? 'https://pili.qiniuapi.com' : 'http://pili.qiniuapi.com'
        end

        # @!visibility private
        def rtc_url(https)
          Utils::Bool.to_bool(https) ? 'https://rtc.qiniuapi.com' : 'http://rtc.qiniuapi.com'
        end
      end

      private

      def normalize_array(ele)
        ele.is_a?(Array) ? ele : [ele].compact
      end
    end

    Region = Zone
  end
end
