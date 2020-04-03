module Proxy::Puppet
  class Environment
    attr_reader :name, :paths

    def initialize(name, paths)
      @name = name.to_s
      @paths = paths
    end

    def to_s
      name
    end
  end
end
