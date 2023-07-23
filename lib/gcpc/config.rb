require "forwardable"

module Gcpc
  class Config
    extend Forwardable

    DEFAULTS = {
      lifecycle_events: {
        # triggers on every 10 seconds if process alive
        beat: []
      }
    }

    def_delegators :@options, :[]

    def initialize
      @options = DEFAULTS
    end

    def on(event, &block)
      raise ArgumentError, "Invalid event name: #{event}" unless @options[:lifecycle_events].keys.include?(event)

      @options[:lifecycle_events][event] << block
    end
  end
end
