require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc::Publisher::Engine do
  describe "#publish" do
    subject { engine.publish(data, attributes) }

    let(:engine) {
      Gcpc::Publisher::Engine.new(
        topic:        topic,
        interceptors: interceptors,
      )
    }
    let(:topic) { double(:topic) }
    let(:data) { "" }
    let(:attributes) { {} }

    context "when interceptors call yield" do
      let(:interceptors) { [hello_interceptor, world_interceptor] }
      let(:hello_interceptor) {
        Class.new(Gcpc::Subscriber::BaseInterceptor) do
          def publish(data, attributes, &block)
            data << "Hello"
            attributes.merge!(hello_interceptor: true)
            yield(data, attributes)
          end
        end
      }
      let(:world_interceptor) {
        Class.new do
          def publish(data, attributes, &block)
            data << ", World"
            attributes.merge!(world_interceptor: true)
            yield(data, attributes)
          end
        end
      }

      it "should call a topic's #publish after calling interceptors' #publish in order" do
        expect(topic).to receive(:publish)
          .with(
            "Hello, World",
            {
              hello_interceptor: true,
              world_interceptor: true,
            }
          ).once

        subject

        # topic and interceptors do not change original data and attributes
        expect(data).to eq ""
        expect(attributes).to eq({})
      end
    end

    context "when interceptors do not call yield" do
      let(:interceptors) { [interceptor] }
      let(:interceptor) {
        Class.new do
          def publish(data, attributes, &block)
            # Do nothing
          end
        end
      }

      it "does not call a topic's #handle" do
        expect(topic).not_to receive(:handle)
        subject
      end
    end

    context "when emulator is running on localhost:8085", emulator: true do
      let(:pubsub_resource_manager) {
        PubsubResourceManager.new(
          project_id:        "project-test-1",
          topic_name:        topic_name,
          emulator_host:     "localhost:8085",
        )
      }
      let(:topic_name) { "topic-test-1" }

      around do |example|
        pubsub_resource_manager.setup_resource!
        example.run
        pubsub_resource_manager.cleanup_resource!
      end

      it "publishes messages" do
        topic = pubsub_resource_manager.topic
        engine = Gcpc::Publisher::Engine.new(topic: topic, interceptors: [])
        r = engine.publish("data1")
        expect(r.data).to eq "data1"
      end
    end
  end

  describe "#publish_batch" do
    context "when emulator is running on localhost:8085", emulator: true do
      let(:pubsub_resource_manager) {
        PubsubResourceManager.new(
          project_id:        "project-test-1",
          topic_name:        topic_name,
          emulator_host:     "localhost:8085",
        )
      }
      let(:topic_name) { "topic-test-1" }

      around do |example|
        pubsub_resource_manager.setup_resource!
        example.run
        pubsub_resource_manager.cleanup_resource!
      end

      it "publishes messages" do
        topic = pubsub_resource_manager.topic
        engine = Gcpc::Publisher::Engine.new(topic: topic, interceptors: [])
        r = engine.publish_batch do |t|
          t.publish("data1")
          t.publish("data2")
          t.publish("data3")
        end
        expect(r.map(&:data)).to eq ["data1", "data2", "data3"]
      end
    end
  end

  describe "#publish_async" do
    context "when emulator is running on localhost:8085", emulator: true do
      let(:pubsub_resource_manager) {
        PubsubResourceManager.new(
          project_id:        "project-test-1",
          topic_name:        topic_name,
          emulator_host:     "localhost:8085",
        )
      }
      let(:topic_name) { "topic-test-1" }
      let(:data) { "data" }

      around do |example|
        pubsub_resource_manager.setup_resource!
        example.run
        pubsub_resource_manager.cleanup_resource!
      end

      context "when block is given" do
        it "publishes messages" do
          topic = pubsub_resource_manager.topic
          engine = Gcpc::Publisher::Engine.new(topic: topic, interceptors: [])
          q = Thread::Queue.new
          3.times do |i|
            engine.publish_async(data) { |r| q.push(r) }
          end
          engine.topic.async_publisher.stop.wait!
          a = []
          while (q.size > 0)
            a << q.pop
          end
          expect(a.map(&:succeeded?)).to eq [true, true, true]
          expect(a.map(&:data)).to eq [data, data, data]
        end
      end
    end
  end
end
