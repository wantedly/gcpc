# Interceptor must implement #publish. Gcpc::Publisher::BaseHandler is a base
# class to implement such a class. You don't have to inherit this, this is only
# for indicating interface.
module Gcpc
  class Publisher
    class BaseInterceptor
      # @param [String] data
      # @param [Hash] attributes
      def publish(data, attributes, &block)
        yield data, attributes
      end
    end
  end
end
