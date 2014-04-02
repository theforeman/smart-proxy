require 'chef/chef_api'

map "/api" do
  run Proxy::Chef::Api
end
