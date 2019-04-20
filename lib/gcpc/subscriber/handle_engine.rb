require "gcpc/subscriber/message"

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
        m = Message.new(message)

        intercept_message!(@interceptors, m) do |mm|
          handle_message(mm)
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
      # @param [Message] message
      # @param [Proc] block
      def intercept_message!(interceptors, message, &block)
        if interceptors.size == 0
          return yield(message)
        end

        i    = interceptors.first
        rest = interceptors[1..-1]

        i.handle(message) do |m|
          intercept_message!(rest, m, &block)
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

      # @param [Message] message
      def handle_message(message)
        @handler.handle(message)
      end

      # @param [Exception] error
      def handle_on_error(error)
        return if !@handler.respond_to?(:on_error)
        @handler.on_error(error)
      end
    end
  end
end
