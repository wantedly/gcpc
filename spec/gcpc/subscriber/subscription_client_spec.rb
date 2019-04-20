require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc::Subscriber::SubscriptionClient do
  describe "#get" do
    subject { subscription_client.get }

    let(:subscription_client) {
      Gcpc::Subscriber::SubscriptionClient.new(
        project_id:        project_id,
        subscription_name: subscription_name,
        credentials:       nil,
        emulator_host:     emulator_host,
        connect_timeout:   connect_timeout,
      )
    }
    let(:project_id) { "project-test-1" }
    let(:subscription_name) { "subscription-test-1" }

    context "when emulator is running on localhost:8085", emulator: true do
      let(:emulator_host) { "localhost:8085" }
      let(:connect_timeout) { 1.0 }

      context "when subscription does not exist" do
        it "returns nil" do
          expect(subject).to eq nil
        end
      end

      context "when subscription exist" do
        let(:pubsub_resource_manager) {
          PubsubResourceManager.new(
            project_id:        project_id,
            topic_name:        "topic-test-1",
            subscription_name: subscription_name,
            emulator_host:     emulator_host,
          )
        }

        around do |example|
          pubsub_resource_manager.setup_resource!
          example.run
          pubsub_resource_manager.cleanup_resource!
        end

        it "returns Google::Cloud::Pubsub::Subscription" do
          expect(subject).to be_a Google::Cloud::Pubsub::Subscription
          expect(subject.name).to eq "projects/project-test-1/subscriptions/subscription-test-1"
        end
      end
    end

    context "when emulator is not running" do
      let(:emulator_host) { "emulator:emulator_port" }
      let(:connect_timeout) { 0.1 }

      it "raises error" do
        expect { subject }.to raise_error(
          'Getting subscription "subscription-test-1" from project "project-test-1" timed out!'
        )
      end
    end
  end
end
