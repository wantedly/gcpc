require "gcpc/subscriber/handle_engine"

module Gcpc
  class Subscriber
    class Engine
      WAIT_INTERVAL = 1

      # @param [Google::Cloud::Pubsub::Subscription] subscription
      # @param [<#handle, #on_error>] interceptors
      # @param [bool] ack_immediately
      # @param [Logger] logger
      def initialize(
        subscription:,
        interceptors:    [],
        ack_immediately: false,
        logger:          DefaultLogger
      )

        @subscription    = subscription
        @interceptors    = interceptors
        @ack_immediately = ack_immediately
        @logger          = logger

        @subscriber      = nil  # @subscriber is created by calling `#run`
        @handler         = nil  # @handler must be registered by `#handle`

        @stopped_mutex = Mutex.new
        @stopped       = false
      end

      # @param [<String>] signals Signals which are used to shutdown subscriber
      #     gracefully.
      def run(signals = ['SIGTERM', 'SIGINT'])
        if @handler.nil?
          raise "You must register handler by #handle before calling #run"
        end

        @logger.info("Starting to subscribe a subscription \"#{@subscription.name}\", will wait for background threads to start...")

        @subscriber = @subscription.listen do |message|
          handle_message(message)
        end
        @subscriber.on_error do |err|
          handle_error(err)
        end
        @subscriber.start

        @logger.info("Started")

        loop_until_receiving_signals(signals)
      end

      def stop
        if @subscriber.nil?
          raise "You must call #run before stopping"
        end

        @stopped_mutex.synchronize do
          # `#stop` may be called multiple times. Only first call can proceed.
          return if @stopped
          @stopped = true
        end

        @logger.info('Stopping, will wait for background threads to exit')

        @subscriber.stop
        @subscriber.wait!

        @logger.info('Stopped, background threads are shutdown')
      end

      # We support registrion of only one handler
      # @param [#handle, #on_error, Class] handler
      def handle(handler)
        @handler = HandleEngine.new(
          handler:      handler,
          interceptors: @interceptors,
        )
      end

    private

      def loop_until_receiving_signals(signals)
        signal_received = false
        signals.each do |signal|
          Signal.trap(signal) { signal_received = true }
        end
        while !(signal_received || stopped?)
          sleep WAIT_INTERVAL
        end

        stop unless stopped?
      end

      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle_message(message)
        ack(message) if @ack_immediately

        begin
          worker_info("Started hanlding message")
          @handler.handle(message)
          worker_info("Finished hanlding message successfully")
        rescue => e
          nack(message) if !@ack_immediately
          raise e  # exception is handled in `#handle_error`
        end

        ack(message) if !@ack_immediately
      end

      def ack(message)
        message.ack!
        worker_info("Acked message")
      end

      def nack(message)
        message.nack!
        worker_info("Nacked message")
      end

      # @param [Exception] error
      def handle_error(error)
        worker_error(error)
        @handler.on_error(error)
      end

      # @param [String] message
      def worker_info(message)
        @logger.info("[Worker #{Thread.current.object_id}] #{message}")
      end

      # @param [Exception] error
      def worker_error(error)
        e_str = "#{error.message}"
        e_str += "\n#{error.backtrace.join("\n")}" if error.backtrace
        @logger.error("[Worker #{Thread.current.object_id}] #{e_str}")
      end

      def stopped?
        @stopped_mutex.synchronize { @stopped }
      end
    end
  end
end
