require "spec_helper"
require "support/pubsub_resource_manager"

describe Gcpc::Subscriber do
  describe "#new" do
    subject {
      Gcpc::Subscriber.new(
        project_id:    project_id,
        subscription:  subscription_name,
        emulator_host: emulator_host,
      )
    }

    let(:project_id) { "project-test-1" }
    let(:subscription_name) { "subscription-test-1" }

    context "when emulator is not running" do
      let(:emulator_host) { "emulator_host:emulator_port" }

      before do
        allow_any_instance_of(Gcpc::Subscriber::SubscriptionClient)
          .to receive(:get)
          .and_return(double(:subscription))
      end

      it "does not raise error" do
        expect { subject }.not_to raise_error
      end
    end

    context "when emulator is running on localhost:8085", emulator: true do
      let(:emulator_host) { "localhost:8085" }

      context "when a subscription exists" do
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

        it "does not raise error" do
          expect { subject }.not_to raise_error
        end
      end

      context "when a subscription does not exist" do
        it "raises error" do
          expect { subject }.to raise_error(
            'Getting subscription "subscription-test-1" from project "project-test-1" failed! The subscription "subscription-test-1" does not exist!'
          )
        end
      end
    end
  end
end
