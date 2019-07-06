# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛 CORS 规则
      class CORSRule
        attr_reader :allowed_origins, :allowed_methods, :allowed_headers, :exposed_headers, :max_age

        def initialize(rules, allowed_origins, allowed_methods)
          allowed_origins = [allowed_origins] unless allowed_origins.is_a?(Array)
          allowed_methods = [allowed_methods] unless allowed_methods.is_a?(Array)
          @rules = rules
          @allowed_origins = allowed_origins
          @allowed_methods = allowed_methods
          @allowed_headers = []
          @exposed_headers = []
          @max_age = nil
        end

        def add_allowed_headers(allowed_headers)
          return self if allowed_headers.nil?

          allowed_headers = [allowed_headers] unless allowed_headers.is_a?(Array)
          @allowed_headers += allowed_headers
          self
        end

        def add_exposed_headers(exposed_headers)
          return self if exposed_headers.nil?

          exposed_headers = [exposed_headers] unless exposed_headers.is_a?(Array)
          @exposed_headers += exposed_headers
          self
        end

        def cache_max_age(max_age)
          max_age = Duration.new(max_age) if max_age.is_a?(Hash)
          @max_age = max_age.to_i
          self
        end

        def as_json
          h = {
            allowed_origin: @allowed_origins,
            allowed_method: @allowed_methods,
            max_age: @max_age
          }
          h[:allowed_header] = @allowed_headers if @allowed_headers.nil? || @allowed_headers.empty?
          h[:exposed_header] = @exposed_headers if @exposed_headers.nil? || @exposed_headers.empty?
          h
        end

        def inspect
          "#<#{self.class.name} @allowed_origins=#{@allowed_origins.inspect}" \
          " @allowed_methods=#{@allowed_methods.inspect} @allowed_headers=#{@allowed_headers.inspect}" \
          " @exposed_headers=#{@exposed_headers} @max_age=#{@max_age.inspect}>"
        end
      end
    end
  end
end
