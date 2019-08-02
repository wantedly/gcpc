require "gcpc/publisher/engine/batch_engine"
require "gcpc/publisher/engine/chained_interceptor"

module Gcpc
  class Publisher
    class Engine
      # @param [Google::Cloud::Pubsub::Topic] topic
      # @param [<#publish>] interceptors
      def initialize(topic:, interceptors:)
        @topic       = topic
        interceptors = interceptors.map { |i| (i.class == Class) ? i.new : i }
        @interceptor = ChainedInterceptor.new(interceptors)
      end

      attr_reader :topic

      # @param [String] data
      # @param [Hash] attributes
      def publish(data, attributes = {})
        d = data.dup
        a = attributes.dup

        @interceptor.intercept!(d, a) do |dd, aa|
          do_publish(dd, aa)
        end
      end

      # @param [Proc] block
      def publish_batch(&block)
        batch_engine = BatchEngine.new(topic: @topic, interceptor: @interceptor)
        yield batch_engine
        batch_engine.flush
      end

      # @param [String] data
      # @param [Hash] attributes
      def publish_async(data, attributes = {}, &block)
        d = data.dup
        a = attributes.dup

        @interceptor.intercept!(d, a) do |dd, aa|
          do_publish_async(dd, aa, &block)
        end
      end

    private

      # @param [String] data
      # @param [Hash] attributes
      def do_publish(data, attributes)
        @topic.publish(data, attributes)
      end

      # @param [String] data
      # @param [Hash] attributes
      # @param [Proc] block
      def do_publish_async(data, attributes, &block)
        @topic.publish_async(data, attributes, &block)
      end
    end
  end
end
