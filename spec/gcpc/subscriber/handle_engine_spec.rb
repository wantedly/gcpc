require "spec_helper"

describe Gcpc::Subscriber::HandleEngine do
  describe "#handle" do
    subject { handle_engine.handle(received_message) }

    let(:handle_engine) {
      Gcpc::Subscriber::HandleEngine.new(
        handler:      handler,
        interceptors: interceptors,
      )
    }
    let(:handler) { double(:handler) }
    let(:received_message) {
      instance_double(
        "Google::Cloud::Pubsub::ReceivedMessage",
        data:       "",
        attributes: {},
      )
    }

    context "when interceptors call yield" do
      let(:interceptors) { [hello_interceptor, world_interceptor] }
      let(:hello_interceptor) {
        Class.new(Gcpc::Subscriber::BaseInterceptor) do
          # @param [Gcpc::Subscriber::Message] message
          # @param [Proc] block
          def handle(message, &block)
            message.data << "Hello"
            message.attributes.merge!(hello_interceptor: true)
            yield(message)
          end
        end
      }
      let(:world_interceptor) {
        Class.new do
          # @param [Gcpc::Subscriber::Message] message
          # @param [Proc] block
          def handle(message, &block)
            message.data << ", World"
            message.attributes.merge!(world_interceptor: true)
            yield(message)
          end
        end
      }

      it "should call a handler's #handle after calling interceptors' #handle in order" do
        handled_message = Gcpc::Subscriber::Message.new(received_message)
        handled_message.data = "Hello, World"
        handled_message.attributes = {
          hello_interceptor: true,
          world_interceptor: true,
        }
        expect(handler).to receive(:handle)
          .with(handled_message)
          .once
        subject

        # handler and interceptors do not change original_message
        expect(received_message.data).to eq ""
        expect(received_message.attributes).to eq({})
      end
    end

    context "when interceptors do not call yield" do
      let(:interceptors) { [interceptor] }
      let(:interceptor) {
        Class.new do
          # @param [Gcpc::Subscriber::Message] message
          # @param [Proc] block
          def handle(message, &block)
            # Do nothing
          end
        end
      }

      it "does not call a handler's #handle" do
        expect(handler).not_to receive(:handle)
        subject
      end
    end
  end

  describe "#on_error" do
    subject { handle_engine.on_error(error) }
    let(:error) { StandardError.new }

    context "with no interceptor" do
      let(:handle_engine) {
        Gcpc::Subscriber::HandleEngine.new(
          handler:      handler,
          interceptors: [],
        )
      }

      let(:handler) { handler_class.new }
      let(:handler_class) {
        Class.new(Gcpc::Subscriber::BaseHandler) do
          # @param [Exception] error
          def on_error(error)
            # Do nothing
          end
        end
      }

      it "calls handler#on_error" do
        expect(handler).to receive(:on_error).with(error).once
        subject
      end
    end

    context "with interceptor" do
      let(:handle_engine) {
        Gcpc::Subscriber::HandleEngine.new(
          handler:      handler,
          interceptors: interceptors,
        )
      }
      let(:handler) { handler_class.new }
      let(:handler_class) {
        Class.new(Gcpc::Subscriber::BaseHandler) do
          # @param [Exception] error
          def on_error(error)
            # Do nothing
          end
        end
      }

      context "when on_error is not implemented in interceptors" do
        let(:interceptors) { [double(:interceptor)] }

        it "skips interceptors" do
          expect(handler).to receive(:on_error).with(error).once
          subject
        end
      end

      context "when on_error is implemented in interceptors" do
        let(:interceptors) { [hello_interceptor, world_interceptor] }
        let(:hello_interceptor) {
          Class.new(Gcpc::Subscriber::BaseInterceptor) do
            # @param [Exception] error
            # @param [Proc] block
            def on_error(error, &block)
              InterceptorOrderContainer.append :hello_interceptor
              yield(error)
            end
          end
        }
        let(:world_interceptor) {
          Class.new(Gcpc::Subscriber::BaseInterceptor) do
            # @param [Exception] error
            # @param [Proc] block
            def on_error(error, &block)
              InterceptorOrderContainer.append :world_interceptor
              yield(error)
            end
          end
        }

        before do
          # InterceptorOrderContainer is used only for observing the order of
          # interceptors which are called in HandleEngine#on_error.
          stub_const "InterceptorOrderContainer", Class.new

          def InterceptorOrderContainer.append(obj)
            container << obj
          end

          def InterceptorOrderContainer.container
            @container ||= []
          end
        end

        it "should call a handler's #on_error after calling interceptors' #on_error in order" do
          expect(handler).to receive(:on_error).with(error).once
          subject
          expect(InterceptorOrderContainer.container).to eq [
            :hello_interceptor,
            :world_interceptor,
          ]
        end
      end

      context "when interceptors do not call yield" do
        let(:interceptors) { [interceptor] }
        let(:interceptor) {
          Class.new(Gcpc::Subscriber::BaseInterceptor) do
            # @param [Exception] error
            # @param [Proc] block
            def on_error(error, &block)
              # Do nothing
            end
          end
        }

        it "does not call a handler's #on_error" do
          expect(handler).not_to receive(:on_error)
          subject
        end
      end
    end
  end
end
