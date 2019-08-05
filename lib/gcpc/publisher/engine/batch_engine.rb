module Gcpc
  class Publisher
    class Engine
      class BatchEngine
        # @param [Google::Cloud::Pubsub::Topic] topic
        # @param [Engine::ChainedInterceptor] interceptor
        def initialize(topic:, interceptor:)
          @topic       = topic
          @interceptor = interceptor
          @messages    = []  # Container of data and attributes
        end

        # Enqueue a message
        #
        # @param [String] data
        # @param [Hash] attributes
        def publish(data, attributes = {})
          d = data.dup
          a = attributes.dup

          @interceptor.intercept!(d, a) do |dd, aa|
            @messages << [dd, aa]
          end
        end

        # Flush all enqueued messages
        def flush
          @topic.publish do |t|
            @messages.each do |(data, attributes)|
              t.publish data, attributes
            end
          end
        end
      end
    end
  end
end
