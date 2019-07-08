# frozen_string_literal: true

module QiniuNg
  module CDN
    # CDN 查询异常
    module Error
      # 预取查询异常
      class PrefetchQueryError < Faraday::Error
      end

      # 刷新查询异常
      class RefreshQueryError < Faraday::Error
      end

      # CDN 查询异常
      class BandwidthQueryError < Faraday::Error
      end
    end
  end
end
