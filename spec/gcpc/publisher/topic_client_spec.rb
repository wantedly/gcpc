require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc::Publisher::TopicClient do
  describe "#get" do
    subject { topic_client.get }

    let(:topic_client) {
      Gcpc::Publisher::TopicClient.new(
        project_id:     project_id,
        topic_name:     topic_name,
        credentials:    nil,
        emulator_host:  emulator_host,
        connect_timeout:connect_timeout,
      )
    }

    let(:project_id) { "project-test-1" }
    let(:topic_name) { "topic-test-1" }

    context "when emulator is running on localhost:8085", emulator: true do
      let(:emulator_host) { "localhost:8085" }
      let(:connect_timeout) { 1.0 }

      context "when topic does not exist" do
        it "returns nil" do
          expect(subject).to eq nil
        end
      end

      context "when subscription exist" do
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

        it "returns Google::Cloud::Pubsub::Subscription" do
          expect(subject).to be_a Google::Cloud::Pubsub::Topic
          expect(subject.name).to eq "projects/project-test-1/topics/topic-test-1"
        end
      end
    end

    context "when emulator is not running" do
      let(:emulator_host) { "emulator:emulator_port" }
      let(:connect_timeout) { 0.1 }

      it "raises error" do
        expect { subject }.to raise_error(
          'Getting topic "topic-test-1" from project "project-test-1" timed out!'
        )
      end
    end
  end
end
