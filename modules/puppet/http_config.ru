require 'puppet/puppet_api'

map "/puppet" do
  run Proxy::Puppet::Api
end
