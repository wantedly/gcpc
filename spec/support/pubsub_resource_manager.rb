class PubsubResourceManager
  # @param [String] project_id
  # @param [String] topic_name
  # @param [String, nil] subscription_name
  # @param [String] emulator_host
  def initialize(project_id:, topic_name:, subscription_name: nil, emulator_host:)
    @project = Google::Cloud::Pubsub.new(
      project_id:    project_id,
      emulator_host: emulator_host,
    )
    @topic_name        = topic_name
    @subscription_name = subscription_name

    # By calling #setup_resource!, @topic and @subscription are created
    @topic        = nil
    @subscription = nil
  end

  attr_reader :topic, :subscription

  def setup_resource!
    # Create topic and subscription in emulator
    @topic = @project.create_topic(@topic_name)

    if @subscription_name
      @subscription = @topic.create_subscription(@subscription_name)
    end
  end

  def cleanup_resource!
    # Delete topic and subscription in emulator

    if @subscription_name
      s = @project.subscription(@subscription_name)
      s.delete
    end

    t = @project.topic(@topic_name)
    t.delete

    @subscription = nil
    @topic        = nil
  end
end
