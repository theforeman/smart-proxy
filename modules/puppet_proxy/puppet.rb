require 'puppet_proxy/puppet_plugin'
module Proxy::Puppet
  class EnvironmentNotFound < StandardError; end
  class DataError < StandardError; end
end
