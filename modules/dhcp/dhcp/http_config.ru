require 'dhcp/dhcp_api'

map "/dhcp" do
  run Proxy::DhcpApi
end
