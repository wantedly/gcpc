require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc::Publisher do
  describe "#new" do
    subject {
      Gcpc::Publisher.new(
        project_id:    project_id,
        topic:         topic_name,
        emulator_host: emulator_host,
      )
    }

    let(:project_id) { "project-test-1" }
    let(:topic_name) { "topic-test-1" }

    context "when emulator is not running" do
      let(:emulator_host) { "emulator_host:emulator_port" }

      before do
        allow_any_instance_of(Gcpc::Publisher::TopicClient)
          .to receive(:get)
          .and_return(double(:topic))
      end

      it "does not raise error" do
        expect { subject }.not_to raise_error
      end
    end

    context "when emulator is running on localhost:8085", emulator: true do
      let(:emulator_host) { "localhost:8085" }

      context "when a topic exist" do
        let(:pubsub_resource_manager) {
          PubsubResourceManager.new(
            project_id:    project_id,
            topic_name:    topic_name,
            emulator_host: emulator_host,
          )
        }

        around do |example|
          pubsub_resource_manager.setup_resource!
          example.run
          pubsub_resource_manager.cleanup_resource!
        end

        it "does not raise error" do
          expect { subject }.not_to raise_error
        end
      end

      context "when a topic does not exist" do
        it "does raises error" do
          expect { subject }.to raise_error(
            'Getting topic "topic-test-1" from project "project-test-1" failed! The topic "topic-test-1" does not exist!'
          )
        end
      end
    end
  end
end
