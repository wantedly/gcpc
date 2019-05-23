# Handler must implement #handle and can implement #on_error.
# Gcpc::Subscriber::BaseHandler is a base class to implement such a class.
# You don't have to inherit this, this is only for indicating interface.
module Gcpc
  class Subscriber
    class BaseHandler
      # @param [String] data
      # @param [Hash] attributes
      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle(data, attributes, message)
        raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      end

      # You don't need to implement #on_error if it is not necessary.
      # @param [Exception] error
      # def on_error(error)
      #   raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      # end
    end
  end
end
