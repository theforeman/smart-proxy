require 'puppet_proxy/puppet_api'

map "/puppet" do
  run Proxy::Puppet::Api
end
