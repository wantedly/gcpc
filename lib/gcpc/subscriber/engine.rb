require "gcpc/subscriber/handle_engine"

module Gcpc
  class Subscriber
    class Engine
      WAIT_INTERVAL = 1
      DEFAULT_HEARTBEAT_FILE_PATH = "/var/tmp/gcpc_worker_heartbeat"
      WORKER_DEAD_THRESHOLD = 30 # second

      # @param [Google::Cloud::Pubsub::Subscription] subscription
      # @param [<#handle, #on_error>] interceptors
      # @param [bool] ack_immediately
      # @param [Logger] logger
      # @param [bool] heartbeat
      # @param [string] heartbeat_file_path
      def initialize(
        subscription:,
        interceptors:    [],
        ack_immediately: false,
        logger:          DefaultLogger,
        heartbeat: false,
        heartbeat_file_path: DEFAULT_HEARTBEAT_FILE_PATH
      )

        @subscription    = subscription
        @interceptors    = interceptors
        @ack_immediately = ack_immediately
        @logger          = logger
        @heartbeat       = heartbeat
        @heartbeat_file_path = heartbeat_file_path
        @heartbeat_queue = []
        @heartbeat_queue_locker = Mutex.new

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

        check_heartbeat

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

      def worker_dead?
        # ・When processing a message, write the thread_id and timestamp at the start time into @heartbeat_queue,
        #   and remove that information from @heartbeat_queue when the processing within that thread is finished.
        # ・If the processing of the message gets stuck, the timestamp will not be removed from @heartbeat_queue.
        # ・Since the application holds as many callback_threads as @subscriber.callback_threads with Subscription,
        #   if the number of threads that have gotten stuck exceeds that callback_threads, it is considered that the worker unable to process Subscription queue.
        number_of_dead_threads = @heartbeat_queue.find_all{ |q| q[:start] < Time.now.to_i - WORKER_DEAD_THRESHOLD }.length 
        return number_of_dead_threads >= @subscriber.callback_threads
      end

      def check_heartbeat
        return unless @heartbeat
        Thread.new do
          loop do
            break if stopped?
            next if worker_dead?

            FileUtils.mkdir_p(File.dirname(@heartbeat_file_path)) unless File.exist?(@heartbeat_file_path)
            open(@heartbeat_file_path, 'w') do |f|
              f.puts(Time.now.to_i)
            end

            sleep 5
          end
        end
      end

      # @param [Google::Cloud::Pubsub::ReceivedMessage] message
      def handle_message(message)
        write_heartbeat_to_store('start')

        ack(message) if @ack_immediately

        begin
          worker_info("Started handling message")
          @handler.handle(message)
          worker_info("Finished hanlding message successfully")
        rescue => e
          nack(message) if !@ack_immediately

          write_heartbeat_to_store('end')

          raise e  # exception is handled in `#handle_error`
        end

        ack(message) if !@ack_immediately
        write_heartbeat_to_store('end')
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

      def write_heartbeat_to_store(type)
        begin
          @heartbeat_queue_locker.synchronize do
            thread_id = Thread.current.object_id

            case type
            when 'start'
              @heartbeat_queue.push({ thread_id: thread_id, start: Time.now.to_i })
            when 'end'
              # GC @heartbeat_queue to avoid memory leak
              @heartbeat_queue.delete_if { |q| q[:thread_id] == thread_id }
            else
              raise "Invalid type passed to write_heartbeat_to_store: #{type}"
            end
          end
        rescue ThreadError => e
          @logger.info("Falied to update heartbeat_queue. thread_id: #{thread_id}, heartbeat_queue: #{@heartbeat_queue}, error: #{e.message}")
        end
      end
    end
  end
end
