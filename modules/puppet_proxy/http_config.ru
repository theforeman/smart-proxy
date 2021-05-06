require 'puppet_proxy/puppet_api'

map "/puppet" do
  use Proxy::Middleware::Authorization
  run Proxy::Puppet::Api
end
