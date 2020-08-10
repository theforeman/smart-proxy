require 'hosts/hosts_api'

map "/hosts" do
  run Proxy::Hosts::Api
end
