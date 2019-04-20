require "google/cloud/pubsub"

module Gcpc
  class Subscriber
    class SubscriptionClient
      DEFAULT_CONNECT_TIMEOUT = 5

      # @param [String] project_id
      # @param [String] subscription_name
      # @param [Google::Cloud::Pubsub::Credentials, String, nil]
      # @param [String, nil] emulator_host
      def initialize(project_id:, subscription_name:, credentials:, emulator_host:, connect_timeout: DEFAULT_CONNECT_TIMEOUT)
        project = Google::Cloud::Pubsub.new(
          project_id:    project_id,
          credentials:   credentials,
          emulator_host: emulator_host,
        )
        @project           = project
        @subscription_name = subscription_name
        @connect_timeout   = connect_timeout
      end

      # @return [Google::Cloud::Pubsub::Subscription]
      def get
        t = nil
        Timeout.timeout(@connect_timeout) do
          t = @project.subscription(@subscription_name)
        end
        t
      rescue Timeout::Error => e
        raise "Getting subscription \"#{@subscription_name}\" from project \"#{@project.project_id}\" timed out!"
      end
    end
  end
end
