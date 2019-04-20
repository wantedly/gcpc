module Gcpc
  class Publisher
    class Engine
      # @param [Google::Cloud::Pubsub::Topic] topic
      # @param [<#publish>] interceptors
      def initialize(topic:, interceptors:)
        @topic        = topic
        @interceptors = interceptors.map { |i| (i.class == Class) ? i.new : i }
      end

      # @param [String] data
      # @param [Hash] attributes
      def publish(data, attributes = {})
        d = data.dup
        a = attributes.dup

        intercept!(@interceptors, d, a) do |dd, aa|
          publish_message(dd, aa)
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
      def publish_message(data, attributes)
        @topic.publish(data, attributes)
      end
    end
  end
end
