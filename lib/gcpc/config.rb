require "forwardable"

module Gcpc
  class Config
    class << self
      attr_accessor :instance
    end

    attr_reader :beat

    def initialize
      @beat = []
      self.class.instance = self
    end

    def on(event, &block)
      raise ArgumentError, "Invalid event name: #{event}" if event != :beat

      @beat << block
    end
  end
end
