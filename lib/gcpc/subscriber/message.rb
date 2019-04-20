module Gcpc
  class Subscriber
    class Message
      extend Forwardable

      # @param [Google::Cloud::Pubsub::ReceivedMessage] original_message
      def initialize(original_message)
        @data             = original_message.data.dup
        @attributes       = original_message.attributes.dup
        @original_message = original_message
      end

      attr_accessor :data, :attributes
      attr_reader :original_message

      def_delegators :@original_message,
        :ack_id,
        :message_id,
        :published_at,
        :acknowledge!,
        :ack!,
        :modify_ack_deadline!,
        :reject!,
        :nack!,
        :ignore!

      def ==(other)
        self.class == other.class &&
          self.data == other.data &&
          self.attributes == other.attributes &&
          self.original_message == other.original_message
      end
    end
  end
end
