require "gcpc/publisher/base_interceptor"
require "gcpc/publisher/engine"
require "gcpc/publisher/topic_client"

module Gcpc
  class Publisher
    # @param [String] project_id
    # @param [String] topic
    # @param [String, Google::Cloud::Pubsub::Credentials, nil] credentials Path
    #     of keyfile or Google::Cloud::Pubsub::Credentials or nil.
    # @param [String, nil] emulator_host Emulator's host or nil.
    # @param [<#publish>] interceptors
    def initialize(
      project_id:,
      topic:,
      credentials:   nil,
      emulator_host: nil,
      interceptors:  []
    )
      topic_client = TopicClient.new(
        project_id:    project_id,
        topic_name:    topic,
        credentials:   credentials,
        emulator_host: emulator_host,
      )

      t = topic_client.get
      if t.nil?
        raise "Getting topic \"#{topic}\" from project \"#{project_id}\" failed! The topic \"#{topic}\" does not exist!"
      end

      @engine = Engine.new(
        topic:        t,
        interceptors: interceptors,
      )
    end

    extend Forwardable

    def_delegators :@engine, :publish
  end
end
