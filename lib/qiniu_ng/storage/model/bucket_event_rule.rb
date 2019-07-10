# frozen_string_literal: true

module QiniuNg
  module Storage
    module Model
      # 七牛存储空间事件规则
      #
      # @example 创建存储空间事件规则
      #   bucket.bucket_event_rules.new(name: 'test_rule1')
      #                            .listen_on(event_types1)
      #                            .callback('http://www.test1.com')
      #                            .create!
      # @example 更新存储空间事件规则
      #   bucket.bucket_event_rules.new(name: 'test_rule1')
      #                            .listen_on(event_types1)
      #                            .callback('http://www.test1.com')
      #                            .replace!
      # @!attribute [r] name
      #   @return [String] 存储空间事件规则名称
      # @!attribute [r] prefix
      #   @return [String] 存储空间事件规则匹配的文件名前缀
      # @!attribute [r] suffix
      #   @return [String] 存储空间事件规则匹配的文件名后缀
      # @!attribute [r] events
      #   @return [Array<QiniuNg::Storage::Model::BucketEventType>] 存储空间事件规则监听的事件列表
      # @!attribute [r] callback_urls
      #   @return [Array<String>] 存储空间事件规则触发后的回调地址列表
      # @!attribute [r] callback_host
      #   @return [String] 存储空间事件规则触发后的回调 HOST
      class BucketEventRule
        attr_reader :name, :prefix, :suffix, :events, :callback_urls, :callback_host

        # @!visibility private
        def initialize(rules, name)
          @rules = rules
          @name = name
          @prefix = nil
          @suffix = nil
          @events = []
          @callback_urls = nil
          @callback_host = nil
        end

        # 设置存储空间事件规则匹配的文件名前缀
        # @param [String] prefix 文件名前缀
        # @return [QiniuNg::Storage::Model::BucketEventRule] 返回上下文
        def start_with(prefix)
          @prefix = prefix.to_s
          self
        end

        # 设置存储空间事件规则匹配的文件名后缀
        # @param [String] suffix 文件名后缀
        # @return [QiniuNg::Storage::Model::BucketEventRule] 返回上下文
        def end_with(suffix)
          @suffix = suffix.to_s
          self
        end

        # 设置存储空间事件规则监听的事件列表
        # @param [QiniuNg::Storage::Model::BucketEventType,
        #   Array<QiniuNg::Storage::Model::BucketEventType>] events 监听的事件列表
        # @return [QiniuNg::Storage::Model::BucketEventRule] 返回上下文
        def listen_on(events)
          events = [events] unless events.is_a?(Array)
          @events = events
          self
        end

        # 设置存储空间事件规则触发后的回调地址
        # @param [String, Array<String>] urls 回调地址列表，第一个地址访问失败后将依次重试
        # @param [String] host 回调 HOST
        # @return [QiniuNg::Storage::Model::BucketEventRule] 返回上下文
        def callback(urls, host: '')
          urls = [urls] unless urls.is_a?(Array)
          @callback_urls = urls
          @callback_host = host
          self
        end

        # 创建存储空间事件规则
        # @param [String] uc_url UC 所在服务器地址，一般无需填写
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [QiniuNg::Storage::BucketEventRules] 返回规则集合
        def create!(uc_url: nil, https: nil, **options)
          @rules.send(:create_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end

        # 更新存储空间事件规则
        # @param [String] uc_url UC 所在服务器地址，一般无需填写
        # @param [Boolean] https 是否使用 HTTPS 协议
        # @param [Hash] options 额外的 Faraday 参数
        # @return [QiniuNg::Storage::BucketEventRules] 返回规则集合
        def replace!(uc_url: nil, https: nil, **options)
          @rules.send(:replace_rule, self, uc_url: uc_url, https: https, **options)
          @rules
        end
        alias update! replace!

        # @!visibility private
        def inspect
          "#<#{self.class.name} @name=#{@name.inspect}> @prefix=#{@prefix.inspect}>" \
          " @suffix=#{@suffix.inspect}> @events=#{@events.inspect}" \
          " @callback_urls=#{@callback_urls.inspect} @callback_host=#{@callback_host.inspect}>"
        end
      end
    end
  end
end
