# frozen_string_literal: true

module QiniuNg
  module CDN
    # 带宽粒度
    class Granularity
      include Ruby::Enum

      define :'5min', '5min'
      define :hour, 'hour'
      define :day, 'day'
    end
  end
end
