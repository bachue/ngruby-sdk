# frozen_string_literal: true

module QiniuNg
  module Utils
    # 七牛布尔值转换库
    module Bool
      extend self

      def to_bool(bool)
        from(bool)
      end

      def to_int(bool)
        from(bool) ? 1 : 0
      end

      private

      def from(bool)
        return false unless bool

        bool != 0
      end
    end
  end
end
