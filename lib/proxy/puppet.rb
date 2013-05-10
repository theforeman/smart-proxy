require 'proxy/util'

module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'

  class Runner
    include Proxy::Log
    include Proxy::Util

    def initialize(opts)
      @nodes = opts[:nodes]
    end

    protected
    attr_reader :nodes
  end
end
