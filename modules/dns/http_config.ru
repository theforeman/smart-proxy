require 'dns/dns_api'

map "/dns" do
  use Proxy::Middleware::Authorization
  run Proxy::Dns::Api
end
