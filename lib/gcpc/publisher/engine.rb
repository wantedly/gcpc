module Gcpc
  class Publisher
    class Engine
      # @param [Google::Cloud::Pubsub::Topic] topic
      # @param [<#publish>] interceptors
      def initialize(topic:, interceptors:)
        @topic        = topic
        @interceptors = interceptors.map { |i| (i.class == Class) ? i.new : i }
      end

      attr_reader :topic

      # @param [String] data
      # @param [Hash] attributes
      def publish(data, attributes = {})
        d = data.dup
        a = attributes.dup

        intercept!(@interceptors, d, a) do |dd, aa|
          do_publish(dd, aa)
        end
      end

      def publish_async(data, attributes = {}, &block)
        d = data.dup
        a = attributes.dup

        intercept!(@interceptors, d, a) do |dd, aa|
          do_publish_async(dd, aa, &block)
        end
      end

    private

      # @param [<#publish>] interceptors
      # @param [String] data
      # @param [Hash] attributes
      # @param [Proc] block
      def intercept!(interceptors, data, attributes, &block)
        if interceptors.size == 0
          return yield(data, attributes)
        end

        i    = interceptors.first
        rest = interceptors[1..-1]

        i.publish(data, attributes) do |d, a|
          intercept!(rest, d, a, &block)
        end
      end

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
