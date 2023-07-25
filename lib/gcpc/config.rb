require "forwardable"

module Gcpc
  class Config
    extend Forwardable

    LIFECYCLE_EVENTS = {
      # triggers on every 10 seconds if process alive
      beat: []
    }

    def_delegators :@lifecycle_events, :[]

    def initialize
      @lifecycle_events = LIFECYCLE_EVENTS
    end

    def on(event, &block)
      raise ArgumentError, "Invalid event name: #{event}" unless @lifecycle_events.keys.include?(event)

      @lifecycle_events[event] << block
    end
  end
end
