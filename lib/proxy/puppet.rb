module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'
  require 'proxy/puppet/runner'

  class << self
    def run *nodes
      if SETTINGS.mcollective
        Proxy::Puppet::Mcollective.run(nodes)
      else
        Proxy::Puppet::PuppetRun.run(nodes)
      end
    end
  end
end
