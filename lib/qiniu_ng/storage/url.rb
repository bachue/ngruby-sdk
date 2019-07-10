# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # @abstract 七牛文件的下载地址
    class URL < String
      # @!visibility private
      def initialize(url)
        replace(url)
      end

      # @!visibility private
      def inspect
        "#<#{self.class.name} #{self}>"
      end
    end
  end
end
