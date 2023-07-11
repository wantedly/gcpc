require "spec_helper"
require "support/pubsub_resource_manager"
require 'fileutils'
require "tempfile"

describe Gcpc::Subscriber::Engine do
  describe "#run and #stop" do
    def heartbeat_value(file)
      return nil if !File.exist?(file)

      File.read(file).chomp.to_i
    end

    let(:temp_heartbeat_file_path) { Tempfile.open(['worker_heartbeat']) }

    context "when emulator is not running" do
      before do
        stub_const "FakeSubscription", Class.new
        class FakeSubscription
          def listen(&block)
            FakeSubscriber.new
          end

          def name
            "/projects/<project-id>/subscription/<subscription-name>"
          end
        end

        stub_const "FakeSubscriber", Class.new
        class FakeSubscriber
          def on_error(&block)
            # Do nothing
          end

          def start
            # Do nothing
          end

          def stop
            # Do nothing
          end

          def wait!
            # Do nothing
          end
        end

        FileUtils.rm(temp_heartbeat_file_path) if File.exist?(temp_heartbeat_file_path)
      end

      let(:engine) {
        Gcpc::Subscriber::Engine.new(
          subscription: FakeSubscription.new,
          logger:       Logger.new(nil),
          heartbeat: true,
          heartbeat_file_path: temp_heartbeat_file_path,
        )
      }

      before do      
        stub_const "NopHandler", Class.new(Gcpc::Subscriber::BaseHandler)
        engine.handle(NopHandler)
      end

      it "must call specified methods of Subscription and Subscriber" do
        expect_any_instance_of(FakeSubscription).to receive(:listen)
          .and_return(FakeSubscriber.new)
        expect_any_instance_of(FakeSubscriber).to receive(:on_error).once
        expect_any_instance_of(FakeSubscriber).to receive(:start).once
        expect(engine).to receive(:check_heartbeat).once
        # Don't do loop in #loop_until_receiving_signals
        expect(engine).to receive(:loop_until_receiving_signals).once

        engine.run

        expect_any_instance_of(FakeSubscriber).to receive(:stop).once
        expect_any_instance_of(FakeSubscriber).to receive(:wait!).once

        engine.stop
      end
    end

    context "when emulator is running on localhost:8085", emulator: true do
      let(:pubsub_resource_manager) {
        PubsubResourceManager.new(
          project_id:        "project-test-1",
          topic_name:        topic_name,
          subscription_name: subscription_name,
          emulator_host:     "localhost:8085",
        )
      }
      let(:topic_name) { "topic-test-1" }
      let(:subscription_name) { "subscription-test-1" }

      around do |example|
        pubsub_resource_manager.setup_resource!
        example.run
        pubsub_resource_manager.cleanup_resource!
      end

      context "when handler succeeds to handle" do
        before do
          stub_const "Handler", Class.new
          class Handler
            def initialize
              @handled = []
            end

            attr_reader :handled

            def handle(data, attributes, message)
              @handled << data
            end
          end
        end

        it "calls Google::Cloud::Pubsub::Subscription#start with heartbeat option" do
          start_at = Time.now.to_i
          subscription = pubsub_resource_manager.subscription
          engine = Gcpc::Subscriber::Engine.new(
            subscription: subscription,
            heartbeat: true,
            heartbeat_file_path: temp_heartbeat_file_path
          )
          handler = Handler.new
          engine.handle(handler)

          # Don't do loop in #loop_until_receiving_signals
          expect(engine).to receive(:loop_until_receiving_signals).once

          engine.run

          topic = pubsub_resource_manager.topic
          topic.publish("published payload")

          sleep 1  # Wait until message is subscribed

          expect(handler.handled.size).to eq 1
          expect(handler.handled.first).to eq "published payload"
          expect(heartbeat_value(temp_heartbeat_file_path)).to be_between(start_at, Time.now.to_i)

          engine.stop
        end

        it "calls Google::Cloud::Pubsub::Subscription#start without heartbeat option" do
          subscription = pubsub_resource_manager.subscription
          engine = Gcpc::Subscriber::Engine.new(
            subscription: subscription,
          )
          handler = Handler.new
          engine.handle(handler)

          # Don't do loop in #loop_until_receiving_signals
          expect(engine).to receive(:loop_until_receiving_signals).once

          engine.run

          topic = pubsub_resource_manager.topic
          topic.publish("published payload")

          sleep 1  # Wait until message is subscribed

          expect(handler.handled.size).to eq 1
          expect(handler.handled.first).to eq "published payload"
          expect(heartbeat_value(Gcpc::Subscriber::Engine::DEFAULT_HEARTBEAT_FILE_PATH)).to eq nil

          engine.stop
        end
      end

      context "when handler fails to handle" do
        before do
          stub_const "Handler", Class.new
          class Handler
            def handle(data, attributes, message)
              raise "Failure occured in #handle!"
            end
          end
        end

        it "calls Subscriber::Engine#nack and Subscriber::Engine#handle_error with heartbeat option" do
          start_at = Time.now.to_i
          subscription = pubsub_resource_manager.subscription
          engine = Gcpc::Subscriber::Engine.new(
            subscription: subscription,
            heartbeat: true,
            heartbeat_file_path: temp_heartbeat_file_path
          )
          handler = Handler.new
          engine.handle(handler)

          # Don't do loop in #loop_until_receiving_signals
          expect(engine).to receive(:loop_until_receiving_signals).once

          expect(engine).to receive(:nack).once
          expect(engine).to receive(:handle_error).once

          engine.run

          topic = pubsub_resource_manager.topic
          topic.publish("published payload")

          sleep 1  # Wait until message is subscribed

          expect(heartbeat_value(temp_heartbeat_file_path)).to be_between(start_at, Time.now.to_i)

          engine.stop
        end
      end
    end
  end

  describe "#handle" do
    let(:engine) {
      Gcpc::Subscriber::Engine.new(
        subscription: subscription
      )
    }
    let(:subscription) { double(:subscription) }

    context "when handler is a object" do
      let(:handler) { double(:handler) }

      it "registers a handler" do
        engine.handle(handler)
        h = engine.instance_variable_get(:@handler)
          .instance_variable_get(:@handler)
        expect(h).to eq handler
      end
    end

    context "when handler is class" do
      before do
        stub_const "NopHandler", Class.new(Gcpc::Subscriber::BaseHandler)
      end

      it "registers a instantiated object" do
        engine.handle(NopHandler)
        h = engine.instance_variable_get(:@handler)
          .instance_variable_get(:@handler)
        expect(h).to be_kind_of(NopHandler)
      end
    end
  end

  describe "#handle_message" do
    subject { engine.send(:handle_message, message) }

    let(:message) { double(:message, data: "", attributes: {}) }
    let(:handler) { double(:handler) }

    before do
      engine.handle(handler)

      stub_const "OrderContainer", Class.new
      class << OrderContainer
        def append(obj)
          container << obj
        end

        def container
          @container ||= []
        end
      end

      def message.ack!
        OrderContainer.append("message is acked")
      end

      def handler.handle(data, attributes, message)
        OrderContainer.append("message is handled")
      end
    end

    context "when ack_immediately is true" do
      let(:engine) {
        Gcpc::Subscriber::Engine.new(
          subscription:    subscription,
          ack_immediately: true,
          logger:          Logger.new(nil),
        )
      }
      let(:subscription) { double(:subscription) }

      it "calls ack! before calling handler#handle" do
        subject
        expect(OrderContainer.container).to eq [
          "message is acked",
          "message is handled",
        ]
      end
    end

    context "when ack_immediately is not set" do
      let(:engine) {
        Gcpc::Subscriber::Engine.new(
          subscription: subscription,
          logger:       Logger.new(nil),
        )
      }
      let(:subscription) { double(:subscription) }

      it "calls ack! after calling handler#handle" do
        subject
        expect(OrderContainer.container).to eq [
          "message is handled",
          "message is acked",
        ]
      end
    end
  end

  describe "#handle_error" do
    subject { engine.send(:handle_error, error) }

    let(:engine) {
      Gcpc::Subscriber::Engine.new(
        subscription: subscription,
        logger:       Logger.new(nil),
      )
    }
    let(:subscription) { double(:subscription) }
    let(:error) { RuntimeError.new }
    let(:handler) { handler_class.new }
    let(:handler_class) {
      Class.new(Gcpc::Subscriber::BaseHandler) do
        def on_error(error)
          # Do nothing
        end
      end
    }

    before do
      engine.handle(handler)
    end

    it "calls handler#on_error" do
      expect(handler).to receive(:on_error).with(error).once
      subject
    end
  end
end
