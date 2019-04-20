module Gcpc
  class Publisher
    class TopicClient
      DEFAULT_CONNECT_TIMEOUT = 5

      # @param [String] project_id
      # @param [String] topic_name
      # @param [Google::Cloud::Pubsub::Credentials, String, nil]
      # @param [String, nil] emulator_host
      def initialize(project_id:, topic_name:, credentials:, emulator_host:, connect_timeout: DEFAULT_CONNECT_TIMEOUT)
        project = Google::Cloud::Pubsub.new(
          project_id:    project_id,
          credentials:   credentials,
          emulator_host: emulator_host,
        )
        @project         = project
        @topic_name      = topic_name
        @connect_timeout = connect_timeout
      end

      # @return [Google::Cloud::Pubsub::Topic]
      def get
        t = nil
        Timeout.timeout(@connect_timeout) do
          t = @project.topic(@topic_name)
        end
        t
      rescue Timeout::Error => e
        raise "Getting topic \"#{@topic_name}\" from project \"#{@project.project_id}\" timed out!"
      end
    end
  end
end
