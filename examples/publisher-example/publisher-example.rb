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

class LogInterceptor < Gcpc::Publisher::BaseInterceptor
  MyLogger = Logger.new(STDOUT)

  def publish(data, attributes)
    MyLogger.info "[Interceptor Log] publish data: \"#{data}\", attributes: #{attributes}"
    yield data, attributes
  end
end

def main
  publisher = Gcpc::Publisher.new(
    project_id:    PROJECT_ID,
    topic:         TOPIC_NAME,
    interceptors:  [LogInterceptor],
    emulator_host: "localhost:8085",
  )
  data = ARGV[0] || "message payload"
  attributes = { publisher: "publisher-example" }
  publisher.publish(data, attributes)
end

main
