module Gcpc
  class Publisher
    class Engine
      class ChainedInterceptor
        # @param [<#publish>] interceptors
        def initialize(interceptors)
          @interceptors = interceptors
        end

        # @param [String] data
        # @param [Hash] attributes
        # @param [Proc] block
        def intercept!(data, attributes, &block)
          do_intercept!(@interceptors, data, attributes, &block)
        end

      private

        # @param [<#publish>] interceptors
        # @param [String] data
        # @param [Hash] attributes
        # @param [Proc] block
        def do_intercept!(interceptors, data, attributes, &block)
          if interceptors.size == 0
            return yield(data, attributes)
          end

          i    = interceptors.first
          rest = interceptors[1..-1]

          i.publish(data, attributes) do |d, a|
            do_intercept!(rest, d, a, &block)
          end
        end
      end
    end
  end
end
