module Ngruby
  module Common
    class Zone
      attr_reader :region
      attr_reader :up_http
      attr_reader :up_https
      attr_reader :up_backup_http
      attr_reader :up_backup_https
      attr_reader :up_ip_http
      attr_reader :up_ip_https
      attr_reader :io_vip_http
      attr_reader :io_vip_https
      attr_reader :rs_http
      attr_reader :rs_https
      attr_reader :rsf_http
      attr_reader :rsf_https
      attr_reader :api_http
      attr_reader :api_https

      def initialize(
          region:,
          up_http: nil,
          up_https: nil,
          up_backup_http: nil,
          up_backup_https: nil,
          up_ip_http: nil,
          up_ip_https: nil,
          io_vip_http: nil,
          io_vip_https: nil,
          rs_http: 'http://rs.qiniu.com',
          rs_https: 'https://rs.qbox.me',
          rsf_http: 'http://rsf.qiniu.com',
          rsf_https: 'https://rsf.qbox.me',
          api_http: 'http://api.qiniu.com',
          api_https: 'https://api.qiniu.com')
        @region = region
        @up_http = up_http
        @up_https = up_https
        @up_backup_http = up_backup_http
        @up_backup_https = up_backup_https
        @up_ip_http = up_ip_http
        @up_ip_https = up_ip_https
        @io_vip_http = io_vip_http
        @io_vip_https = io_vip_https
        @rs_http = rs_http
        @rs_https = rs_https
        @rsf_http = rsf_http
        @rsf_https = rsf_https
        @api_http = api_http
        @api_https = api_https
      end

      class << self
        def auto(uc_server: AutoZone::UcServer)
          AutoZone.new(uc_server: uc_server)
        end

        def huadong
          new(region: 'z0'.freeze,
              up_http: 'http://up.qiniu.com'.freeze,
              up_https: 'https://up.qbox.me'.freeze,
              up_backup_http: 'http://upload.qiniu.com'.freeze,
              up_backup_https: 'https://upload.qbox.me'.freeze,
              io_vip_http: 'http://iovip.qbox.me'.freeze,
              io_vip_https: 'https://iovip.qbox.me'.freeze,
              rs_http: 'http://rs.qiniu.com'.freeze,
              rs_https: 'https://rs.qbox.me'.freeze,
              rsf_http: 'http://rsf.qiniu.com'.freeze,
              rsf_https: 'https://rsf.qbox.me'.freeze,
              api_http: 'http://api.qiniu.com'.freeze,
              api_https: 'https://api.qiniu.com'.freeze).
              freeze
        end
        alias_method :zone0, :huadong

        def qvm_huadong
          new(region: 'z0'.freeze,
              up_http: 'http://free-qvm-z0-xs.qiniup.com'.freeze,
              up_https: 'https://free-qvm-z0-xs.qiniup.com'.freeze,
              up_backup_http: 'http://free-qvm-z0-xs.qiniup.com'.freeze,
              up_backup_https: 'https://free-qvm-z0-xs.qiniup.com'.freeze,
              io_vip_http: 'http://iovip.qbox.me'.freeze,
              io_vip_https: 'https://iovip.qbox.me'.freeze,
              rs_http: 'http://rs.qiniu.com'.freeze,
              rs_https: 'https://rs.qbox.me'.freeze,
              rsf_http: 'http://rsf.qiniu.com'.freeze,
              rsf_https: 'https://rsf.qbox.me'.freeze,
              api_http: 'http://api.qiniu.com'.freeze,
              api_https: 'https://api.qiniu.com'.freeze).
              freeze
        end
        alias_method :qvm_zone0, :qvm_huadong

        def huabei
          new(region: 'z1'.freeze,
              up_http: 'http://up-z1.qiniu.com'.freeze,
              up_https: 'https://up-z1.qbox.me'.freeze,
              up_backup_http: 'http://upload-z1.qiniu.com'.freeze,
              up_backup_https: 'https://upload-z1.qbox.me'.freeze,
              io_vip_http: 'http://iovip-z1.qbox.me'.freeze,
              io_vip_https: 'https://iovip-z1.qbox.me'.freeze,
              rs_http: 'http://rs-z1.qiniu.com'.freeze,
              rs_https: 'https://rs-z1.qbox.me'.freeze,
              rsf_http: 'http://rsf-z1.qiniu.com'.freeze,
              rsf_https: 'https://rsf-z1.qbox.me'.freeze,
              api_http: 'http://api-z1.qiniu.com'.freeze,
              api_https: 'https://api-z1.qiniu.com'.freeze).
              freeze
        end
        alias_method :zone1, :huabei

        def qvm_huabei
          new(region: 'z1'.freeze,
              up_http: 'http://free-qvm-z1-zz.qiniup.com'.freeze,
              up_https: 'https://free-qvm-z1-zz.qiniup.com'.freeze,
              up_backup_http: 'http://free-qvm-z1-zz.qiniup.com'.freeze,
              up_backup_https: 'https://free-qvm-z1-zz.qiniup.com'.freeze,
              io_vip_http: 'http://iovip-z1.qbox.me'.freeze,
              io_vip_https: 'https://iovip-z1.qbox.me'.freeze,
              rs_http: 'http://rs-z1.qiniu.com'.freeze,
              rs_https: 'https://rs-z1.qbox.me'.freeze,
              rsf_http: 'http://rsf-z1.qiniu.com'.freeze,
              rsf_https: 'https://rsf-z1.qbox.me'.freeze,
              api_http: 'http://api-z1.qiniu.com'.freeze,
              api_https: 'https://api-z1.qiniu.com'.freeze).
              freeze
        end
        alias_method :qvm_zone1, :qvm_huabei

        def huanan
          new(region: 'z2'.freeze,
              up_http: 'http://up-z2.qiniu.com'.freeze,
              up_https: 'https://up-z2.qbox.me'.freeze,
              up_backup_http: 'http://upload-z2.qiniu.com'.freeze,
              up_backup_https: 'https://upload-z2.qbox.me'.freeze,
              io_vip_http: 'http://iovip-z2.qbox.me'.freeze,
              io_vip_https: 'https://iovip-z2.qbox.me'.freeze,
              rs_http: 'http://rs-z2.qiniu.com'.freeze,
              rs_https: 'https://rs-z2.qbox.me'.freeze,
              rsf_http: 'http://rsf-z2.qiniu.com'.freeze,
              rsf_https: 'https://rsf-z2.qbox.me'.freeze,
              api_http: 'http://api-z2.qiniu.com'.freeze,
              api_https: 'https://api-z2.qiniu.com'.freeze).
              freeze
        end
        alias_method :zone2, :huanan

        def beimei
          new(region: 'na0'.freeze,
              up_http: 'http://up-na0.qiniu.com'.freeze,
              up_https: 'https://up-na0.qbox.me'.freeze,
              up_backup_http: 'http://upload-na0.qiniu.com'.freeze,
              up_backup_https: 'https://upload-na0.qbox.me'.freeze,
              io_vip_http: 'http://iovip-na0.qbox.me'.freeze,
              io_vip_https: 'https://iovip-na0.qbox.me'.freeze,
              rs_http: 'http://rs-na0.qiniu.com'.freeze,
              rs_https: 'https://rs-na0.qbox.me'.freeze,
              rsf_http: 'http://rsf-na0.qiniu.com'.freeze,
              rsf_https: 'https://rsf-na0.qbox.me'.freeze,
              api_http: 'http://api-na0.qiniu.com'.freeze,
              api_https: 'https://api-na0.qiniu.com'.freeze).
              freeze
        end
        alias_method :zone_na0, :beimei
        alias_method :north_america, :beimei

        def xinjiapo
          new(region: 'as0'.freeze,
              up_http: 'http://up-as0.qiniu.com'.freeze,
              up_https: 'https://up-as0.qbox.me'.freeze,
              up_backup_http: 'http://upload-as0.qiniu.com'.freeze,
              up_backup_https: 'https://upload-as0.qbox.me'.freeze,
              io_vip_http: 'http://iovip-as0.qbox.me'.freeze,
              io_vip_https: 'https://iovip-as0.qbox.me'.freeze,
              rs_http: 'http://rs-as0.qiniu.com'.freeze,
              rs_https: 'https://rs-as0.qbox.me'.freeze,
              rsf_http: 'http://rsf-as0.qiniu.com'.freeze,
              rsf_https: 'https://rsf-as0.qbox.me'.freeze,
              api_http: 'http://api-as0.qiniu.com'.freeze,
              api_https: 'https://api-as0.qiniu.com'.freeze).
              freeze
        end
        alias_method :zone_as0, :xinjiapo
        alias_method :singapore, :xinjiapo
      end
    end
  end
end
