require "gcpc/version"
require "gcpc/publisher"
require "gcpc/subscriber"
require "gcpc/config"

module Gcpc
  def self.default_config
      @config ||= Gcpc::Config.new
  end

  def self.configure
    yield default_config
  end
end
