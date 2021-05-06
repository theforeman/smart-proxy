require 'dhcp/dhcp_api'

map "/dhcp" do
  use Proxy::Middleware::Authorization
  run Proxy::DhcpApi
end
