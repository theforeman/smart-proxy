require 'test/benchmark_helper'
require 'dhcp_common/dhcp_common'

class Ipv4AddressArithmeticTests < Test::Unit::TestCase

  def test_ipv4_to_i
    assert_equal 0xffffffff, Proxy::DHCP.ipv4_to_i("255.255.255.255")
    assert_equal 0x7f000001, Proxy::DHCP.ipv4_to_i("127.0.0.1")
    assert_equal 0xc0a80000, Proxy::DHCP.ipv4_to_i("192.168.0.0")
  end

  def test_i_to_ipv4
    assert_equal "255.255.255.255", Proxy::DHCP.i_to_ipv4(0xffffffff)
    assert_equal "127.0.0.1", Proxy::DHCP.i_to_ipv4(0x7f000001)
    assert_equal "192.168.0.0", Proxy::DHCP.i_to_ipv4(0xc0a80000)
  end
end
