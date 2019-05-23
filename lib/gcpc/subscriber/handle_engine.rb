module Gcpc
  class Subscriber
    # HandleEngine handle messages and exceptions with interceptors.
    class HandleEngine
      # @param [#handle, #on_error, Class] handler
      # @param [<#handle, #on_error, Class>] interceptors
      def initialize(handler:, interceptors:)
        @handler      = (handler.class == Class) ? handler.new : handler
        @interceptors = interceptors.map { |i| (i.class == Class) ? i.new : i }
      end

      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle(message)
        d = message.data.dup
        a = message.attributes.dup

        intercept_message!(@interceptors, d, a, message) do |dd, aa, m|
          handle_message(dd, aa, m)
        end
      end

      # @param [Exception] error
      def on_error(error)
        intercept_error!(@interceptors, error) do |e|
          handle_on_error(e)
        end
      end

    private

      # @param [<#handle>] interceptors
      # @param [String] data
      # @param [Hash] attributes
      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      # @param [Proc] block
      def intercept_message!(interceptors, data, attributes, message, &block)
        if interceptors.size == 0
          return yield(data, attributes, message)
        end

        i    = interceptors.first
        rest = interceptors[1..-1]

        i.handle(data, attributes, message) do |d, a, m|
          intercept_message!(rest, d, a, m, &block)
        end
      end

      # @param [<#on_error>] interceptors
      # @param [Exception] error
      # @param [Proc] block
      def intercept_error!(interceptors, error, &block)
        return yield(error) if interceptors.size == 0

        i    = interceptors.first
        rest = interceptors[1..-1]

        if !i.respond_to?(:on_error)
          # If #on_error is not implemented in the interceptor, it is simply
          # skipped.
          return intercept_error!(rest, error, &block)
        end

        i.on_error(error) do |e|
          intercept_error!(rest, e, &block)
        end
      end

      # @param [String] data
      # @param [Hash] attributes
      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle_message(data, attributes, message)
        @handler.handle(data, attributes, message)
      end

      # @param [Exception] error
      def handle_on_error(error)
        return if !@handler.respond_to?(:on_error)
        @handler.on_error(error)
      end
    end
  end
end
