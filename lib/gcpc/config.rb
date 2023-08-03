require "singleton"

module Gcpc
  class Config
    include Singleton
    attr_reader :beat

    def initialize
      @beat = []
    end

    def on(event, &block)
      raise ArgumentError, "Invalid event name: #{event}" if event != :beat

      @beat << block
    end
  end
end
