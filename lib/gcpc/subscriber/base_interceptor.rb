require "gcpc/subscriber/message"

# Interceptor must implement #handle and can implement #on_error.
# Gcpc::Subscriber::BaseHandler is a base class to implement such a class.
# You don't have to inherit this, this is only for indicating interface.
module Gcpc
  class Subscriber
    class BaseInterceptor
      # @param [Message] message
      # @param [Proc] block
      def handle(message, &block)
        yield message
      end

      # You don't need to implement #on_error is it is not necessary.
      # @param [Exception] error
      # @param [Plock] block
      # def on_error(error, &block)
      #   yield error
      # end
    end
  end
end
