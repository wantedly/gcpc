require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc do
  describe "e2e", emulator: true do
    let(:project_id) { "project-test-1" }
    let(:topic_name) { "topic-test-1" }
    let(:subscription_name) { "subscription-test-1" }
    let(:emulator_host) { "localhost:8085" }

    let(:pubsub_resource_manager) {
      PubsubResourceManager.new(
        project_id:        project_id,
        topic_name:        topic_name,
        subscription_name: subscription_name,
        emulator_host:     emulator_host,
      )
    }

    around do |example|
      pubsub_resource_manager.setup_resource!
      example.run
      pubsub_resource_manager.cleanup_resource!
    end

    before do
      allow_any_instance_of(Gcpc::Subscriber::Engine).to receive(:loop_until_receiving_signals)
    end

    it "succeeds to publish and subscribe messages" do
      stub_handler = double(:stub_handler)
      expect(stub_handler).to receive(:handle).once

      subscriber = Gcpc::Subscriber.new(
        project_id:    project_id,
        subscription:  subscription_name,
        emulator_host: "localhost:8085",
      )
      subscriber.handle(stub_handler)

      # Start subscriber in another thread
      subscriber_thread = Thread.new(subscriber) do |subscriber|
        subscriber.run
      end

      publisher = Gcpc::Publisher.new(
        project_id:    project_id,
        topic:         topic_name,
        emulator_host: emulator_host,
      )
      data = "message payload"
      attributes = { publisher: "publisher-example" }
      publisher.publish(data, attributes)

      sleep 1  # Wait for publish / subscribe a message

      # Stop the subscriber and its thread.
      subscriber.stop
      subscriber_thread.join
    end

    it "succeeds to publish_batch and subscribe messages" do
      stub_handler = double(:stub_handler)
      expect(stub_handler).to receive(:handle).once

      subscriber = Gcpc::Subscriber.new(
        project_id:    project_id,
        subscription:  subscription_name,
        emulator_host: "localhost:8085",
      )
      subscriber.handle(stub_handler)

      # Start subscriber in another thread
      subscriber_thread = Thread.new(subscriber) do |subscriber|
        subscriber.run
      end

      publisher = Gcpc::Publisher.new(
        project_id:    project_id,
        topic:         topic_name,
        emulator_host: emulator_host,
      )
      data = "message payload"
      attributes = { publisher: "publisher-example" }
      publisher.publish_batch do |t|
        t.publish(data, attributes)
      end

      sleep 1  # Wait for publish / subscribe a message

      # Stop the subscriber and its thread.
      subscriber.stop
      subscriber_thread.join
    end

    it "succeeds to publish_async and subscribe messages" do
      stub_handler = double(:stub_handler)
      expect(stub_handler).to receive(:handle).once

      subscriber = Gcpc::Subscriber.new(
        project_id:    project_id,
        subscription:  subscription_name,
        emulator_host: "localhost:8085",
      )
      subscriber.handle(stub_handler)

      # Start subscriber in another thread
      subscriber_thread = Thread.new(subscriber) do |subscriber|
        subscriber.run
      end

      publisher = Gcpc::Publisher.new(
        project_id:    project_id,
        topic:         topic_name,
        emulator_host: emulator_host,
      )
      data = "message payload"
      attributes = { publisher: "publisher-example" }
      publisher.publish_async(data, attributes)
      publisher.topic.async_publisher.stop.wait!  # Wait for asynchronous publishing

      sleep 1  # Wait for publish / subscribe a message

      # Stop the subscriber and its thread.
      subscriber.stop
      subscriber_thread.join
    end
  end
end
