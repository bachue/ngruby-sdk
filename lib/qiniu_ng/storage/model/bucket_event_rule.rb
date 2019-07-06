# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛存储空间事件规则
      class BucketEventRule
        attr_reader :name, :prefix, :suffix, :events, :callback_urls, :callback_host

        def initialize(rules, name)
          @rules = rules
          @name = name
          @prefix = nil
          @suffix = nil
          @events = []
          @callback_urls = nil
          @callback_host = nil
        end

        def start_with(prefix)
          @prefix = prefix.to_s
          self
        end

        def end_with(suffix)
          @suffix = suffix.to_s
          self
        end

        def listen_on(events)
          events = [events] unless events.is_a?(Array)
          @events = events
          self
        end

        def callback(urls, host: '')
          urls = [urls] unless urls.is_a?(Array)
          @callback_urls = urls
          @callback_host = host
          self
        end

        def create!(uc_url: nil, https: nil, **options)
          @rules.send(:create_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end

        def replace!(uc_url: nil, https: nil, **options)
          @rules.send(:replace_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end
        alias update! replace!
      end
    end
  end
end
