require 'externalipam/ipam_api'

map '/ipam' do
  run Proxy::Ipam::Api
end
