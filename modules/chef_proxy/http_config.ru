require 'chef_proxy/chef_api'

map "/api" do
  run Proxy::Chef::Api
end
