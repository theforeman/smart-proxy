require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/server'

class Proxy::DHCPSubnetTest < Test::Unit::TestCase
  def setup
    @network = "192.168.0.0"
    @netmask = "255.255.255.0"
    @subnet = Proxy::DHCP::Subnet.new @network, @netmask
  end

  def test_should_convert_to_string
    assert_equal @subnet.to_s, "#{@network}/#{@netmask}"
  end

  def test_should_not_save_invalid_network_addresses
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Subnet.new("1..1.1", @netmask)
    end
  end

  def test_should_not_save_invalid_router_addresses
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :routers => ["192.168..1"])
    end
  end

  def test_should_not_save_invalid_range
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :range => ["192.168.0..", "192.168.0.50"])
    end
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :range => ["192.168.0.3", "192.168.0.."])
    end
    assert_raise Proxy::DHCP::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :range => ["192.168.0.3", "192.168.1.100"])
    end
    assert_raise Proxy::DHCP::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :range => ["192.168.1.3", "192.168.0.100"])
    end
    assert_raise Proxy::DHCP::Error do
      Proxy::DHCP::Subnet.new(@network, @netmask, :range => ["192.168.0.100", "192.168.0.3"])
    end
  end

  def test_should_not_save_invalid_netmask
    netmask = "XYZxxVVcc123"
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Subnet.new(@network, netmask)
    end
  end

  def test_subnet_includes_ip
    assert @subnet.include?("192.168.0.10")
  end

  def test_subnet_does_not_include_ip
    assert @subnet.include?("192.168.5.10") == false
  end

  def test_should_provide_range_excluding_network_address
    assert_equal "192.168.0.1", @subnet.subnet_range_addresses[0]
  end

  def test_should_provide_range_excluding_broadcast_address
    assert_equal "192.168.0.254", @subnet.subnet_range_addresses[1]
  end

  def test_range
    assert_equal @subnet.range, "192.168.0.1-192.168.0.254"
  end

  def test_options_should_be_a_hash
    assert_kind_of Hash, @subnet.options
  end

  def test_equality
    assert_equal ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'a.b.c'), ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'a.b.c')
    assert_not_equal ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'a.b.c'),
                     ::Proxy::DHCP::Subnet.new('1.1.1.0', @netmask, :domain_name => 'a.b.c')
    assert_not_equal ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'a.b.c'),
                     ::Proxy::DHCP::Subnet.new(@network, '255.255.255.128', :domain_name => 'a.b.c')
    assert_not_equal ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'a.b.c'),
                     ::Proxy::DHCP::Subnet.new(@network, @netmask, :domain_name => 'd.e.f')
  end
end
