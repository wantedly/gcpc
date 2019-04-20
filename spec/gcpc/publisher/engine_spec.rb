require "spec_helper"

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
  end
end
