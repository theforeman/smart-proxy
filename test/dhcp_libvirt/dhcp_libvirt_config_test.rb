require 'test_helper'
require 'dhcp_libvirt/dhcp_libvirt'

class DhcpLibvirtConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    ::Proxy::DHCP::Libvirt::Plugin.load_test_settings()
    assert_equal 'default', ::Proxy::DHCP::Libvirt::Plugin.settings.network
    assert_equal 'qemu:///system', ::Proxy::DHCP::Libvirt::Plugin.settings.url
  end
end
