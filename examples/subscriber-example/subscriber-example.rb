require "gcpc"

# Please execute commands below.
#
# ```
# $ gcloud beta emulators pubsub start
# $ bundle exec ruby examples/subscriber-example/subscriber-example.rb
# $ bundle exec ruby examples/publisher-example/publisher-example.rb
# ```

PROJECT_ID = "project-example-1"
TOPIC_NAME = "topic-example-1"
SUBSCRIPTION_NAME = "subscription-example-1"

MyLogger = Logger.new(STDOUT)

class LogInterceptor < Gcpc::Subscriber::BaseInterceptor
  def handle(data, attributes, message)
    MyLogger.info "[Interceptor Log] #{message.inspect}"
    MyLogger.info "[Interceptor Log] data: #{data}"
    MyLogger.info "[Interceptor Log] attributes: #{attributes}"
    yield data, attributes, message
  end
end

class LogHandler < Gcpc::Subscriber::BaseHandler
  def handle(data, attributes, message)
    MyLogger.info "[Handler Log] #{message.inspect}"
    MyLogger.info "[Handler Log] data: #{data}"
    MyLogger.info "[Handler Log] attributes: #{attributes}"
  end
end

# We create topic and subscription only for demonstration.
def with_setup_subscription(&block)
  project = Google::Cloud::Pubsub.new(
    project_id:    PROJECT_ID,
    emulator_host: "localhost:8085",
  )
  if (topic = project.topic(TOPIC_NAME)).nil?
    # Create a topic if necessary
    topic = project.create_topic(TOPIC_NAME)
  end
  if (subscription = topic.subscription(SUBSCRIPTION_NAME)).nil?
    # Create a subscription if necessary
    subscription = topic.create_subscription(SUBSCRIPTION_NAME)
  end

  yield

ensure
  topic.delete
  subscription.delete
end

def run
  subscriber = Gcpc::Subscriber.new(
    project_id:    PROJECT_ID,
    subscription:  SUBSCRIPTION_NAME,
    interceptors:  [LogInterceptor],
    emulator_host: "localhost:8085",
  )
  subscriber.handle(LogHandler)
  subscriber.run
end

def main
  with_setup_subscription do
    run
  end
end

main
