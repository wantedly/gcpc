require "gcpc/subscriber/base_handler"
require "gcpc/subscriber/base_interceptor"
require "gcpc/subscriber/default_logger"
require "gcpc/subscriber/engine"
require "gcpc/subscriber/subscription_client"

## About gcpc
#
# - [ ] README.md
#   - [ ] remove sample code below
# - [ ] examples/README.md

## About gcpc-interceptors (seems to https://github.com/cookpad/griffin-interceptors)
# - [ ] impl gcpc-interceptors

# subscriber = Gcpc::Subscriber.new(
#   project_id:      "xxx",
#   subscription:    "xxx",
#   credentials:     "xxx",  # string of path or `Google::Cloud::Pubsub::Credential` object.
#   interceptors:    [xxx],
#   ack_immediately: true,
#   logger:          Rails.logger,
# )
# subscriber.handle(XXXHandler)
# subscriber.run

module Gcpc
  class Subscriber
    # @param [String] project_id
    # @param [String] subscription
    # @param [String, Google::Cloud::Pubsub::Credentials, nil] credentials Path
    #     of keyfile or Google::Cloud::Pubsub::Credentials or nil.
    # @param [String, nil] emulator_host Emulator's host or nil.
    # @param [<#handle, #on_error>] interceptors
    # @param [bool] ack_immediately
    # @param [Logger] logger
    def initialize(
      project_id:,
      subscription:,
      credentials:     nil,
      emulator_host:   nil,
      interceptors:    [],
      ack_immediately: false,
      logger:          DefaultLogger
    )
      subscription_client = SubscriptionClient.new(
        project_id:        project_id,
        subscription_name: subscription,
        credentials:       credentials,
        emulator_host:     emulator_host,
      )

      s = subscription_client.get
      if s.nil?
        raise "Getting subscription \"#{subscription}\" from project \"#{project_id}\" failed! The subscription \"#{subscription}\" does not exist!"
      end

      @engine = Engine.new(
        subscription:    s,
        interceptors:    interceptors,
        ack_immediately: ack_immediately,
        logger:          logger,
      )
    end

    extend Forwardable

    def_delegators :@engine, :handle, :run
  end
end
