# frozen_string_literal: true

module QiniuNg
  module Utils
    # @!visibility private
    module Bool
      extend self

      def to_bool(bool, omitempty: false)
        b = from(bool)
        return b if b

        omitempty ? nil : b
      end

      def to_int(bool, omitempty: false)
        v = from(bool) ? 1 : 0
        return v if v == 1

        omitempty ? nil : v
      end

      private

      def from(bool)
        return false unless bool

        bool != 0
      end
    end
  end
end
