# frozen_string_literal: true

require 'forwardable'

module QiniuNg
  module Storage
    # 七牛文件的下载地址
    class URL < String
      def initialize(url)
        replace(url)
      end

      def inspect
        "#<#{self.class.name} #{self}>"
      end
    end
  end
end
