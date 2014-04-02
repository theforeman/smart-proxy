require 'dns/dns_api'

map "/dns" do
  run Proxy::Dns::Api
end
