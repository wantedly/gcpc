require "gcpc/subscriber/handle_engine"

module Gcpc
  class Subscriber
    class Engine
      WAIT_INTERVAL = 1
      WORKER_DEAD_THRESHOLD = 30 # second
      BEAT_INTERVAL = 10
      HEART_BEAT_WORKER_NAME = 'heartbeat-worker'

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
        @subscriber_thread_status = {}
        @subscriber_thread_status_mutex = Mutex.new
        @heartbeat_worker_thread = nil

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

        run_heartbeat_worker

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

        begin
          @heartbeat_worker_thread&.wakeup
        rescue ThreadError => e
          @logger.error(e.message)
        end

        @heartbeat_worker_thread&.join

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

      def run_heartbeat_worker
        @heartbeat_worker_thread = Thread.new do
          @logger.info("Starting heartbeat worker...")
          begin
            loop do
              break if stopped?

              next unless alive?

              Gcpc::Config.instance.beat.each(&:call)

              sleep BEAT_INTERVAL
            end
          ensure
            @logger.info("heartbeat worker stopped")
          end
        end

        @heartbeat_worker_thread.name = HEART_BEAT_WORKER_NAME
      end

      def alive?
        # ・When processing a message, write the thread_id and timestamp at the start time into @subscriber_thread_status,
        #   and remove that information from @subscriber_thread_status when the processing within that thread is finished.
        #   @subscriber_thread_status = {#<Thread:0x000000010302cd40 run>=>1690757417}
        # ・If the processing of the message gets stuck, the key, value will not be removed from @subscriber_thread_status.
        # ・Since the application holds as many callback_threads as @subscriber.callback_threads with Subscription,
        #   if the number of threads that have gotten stuck exceeds that callback_threads, it is considered that the worker unable to process Subscription queue.
        return false unless @subscriber && @subscriber.started?
        return false if @subscriber.stopped?

        number_of_dead_threads = @subscriber_thread_status.count { |_, v| v < Time.now.to_i - WORKER_DEAD_THRESHOLD }

        return @subscriber.callback_threads > number_of_dead_threads
      end


      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle_message(message)
        write_heartbeat_to_subscriber_thread_status

        ack(message) if @ack_immediately

        begin
          worker_info("Started handling message")
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
        cleanup_subscriber_thread_status
        worker_info("Acked message")
      end

      def nack(message)
        message.nack!
        cleanup_subscriber_thread_status
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
      
      def write_heartbeat_to_subscriber_thread_status
        begin
          @subscriber_thread_status_mutex.synchronize do
            @subscriber_thread_status[Thread.current] = Time.now.to_i
          end
        rescue ThreadError => e
          @logger.info("Falied to write subscriber_thread_status. thread_id: #{Thread.current.object_id}, subscriber_thread_status: #{@subscriber_thread_status}, error: #{e.message}")
        end
      end

      def cleanup_subscriber_thread_status
        begin
          @subscriber_thread_status_mutex.synchronize do
            # cleanup to avoid memory leak
            @subscriber_thread_status.delete(Thread.current)
          end
        rescue ThreadError => e
          @logger.info("Falied to cleanup subscriber_thread_status. thread_id: #{Thread.current.object_id}, subscriber_thread_status: #{@subscriber_thread_status}, error: #{e.message}")
        end
      end
    end
  end
end
