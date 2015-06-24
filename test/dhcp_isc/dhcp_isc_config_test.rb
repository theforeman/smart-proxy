require 'test_helper'
require 'dhcp_isc/dhcp_isc'

class DhcpIscConfigTest < ::Test::Unit::TestCase
  def test_default_configuration
    Proxy::DHCP::ISC::Plugin.load_test_settings({})
    assert_equal '7911', Proxy::DHCP::ISC::Plugin.settings.omapi_port
    assert_equal '/etc/dhcp/dhcpd.conf', Proxy::DHCP::ISC::Plugin.settings.config
    assert_equal '/var/lib/dhcpd/dhcpd.leases', Proxy::DHCP::ISC::Plugin.settings.leases
  end
end