require 'test_helper'
require "proxy/dhcp"

class DHCPServerTest < Test::Unit::TestCase

  def setup
    @server = Proxy::DHCP::Server.new("testcase")
    @subnet = Proxy::DHCP::Subnet.new(@server, "192.168.0.0", "255.255.255.0")
    @record = Proxy::DHCP::Record.new(:subnet => @subnet, :ip => "192.168.0.11", :mac => "aa:bb:cc:dd:ee:ff")
  end

  def test_should_provide_subnets
    assert_respond_to @server, :subnets
  end

  def test_should_add_subnet
    counter = @server.subnets.size
    Proxy::DHCP::Subnet.new(@server, "192.168.1.0", "255.255.255.0")
    assert_equal counter+1, @server.subnets.size
  end

  def test_should_not_add_duplicate_subnets
    assert_raise Proxy::DHCP::Error do
      Proxy::DHCP::Subnet.new(@server, "192.168.0.0", "255.255.255.0")
    end
  end

  def test_should_find_subnet_based_on_network
    assert_equal @subnet, @server.find_subnet("192.168.0.0")
  end

  def test_should_find_subnet_based_on_dhcp_record
    assert_equal @subnet, @server.find_subnet(@record)
  end

  def test_should_find_subnet_based_on_ipaddr
    ip = IPAddr.new "192.168.0.11"
    assert_equal @subnet, @server.find_subnet(ip)
  end

  def test_should_find_record_based_on_ip
    assert_equal @record, @server.find_record("192.168.0.11")
  end

  def test_should_find_record_based_on_dhcp_record
    assert_equal @record, @server.find_record(@record)
  end

  def test_should_find_record_based_on_ipaddr
    ip = IPAddr.new "192.168.0.11"
    assert_equal @record, @server.find_record(ip)
  end

  def test_should_retrun_nil_when_no_subnet
    subnet = @server.find_subnet IPAddr.new("1.20.76.0")
    assert_nil subnet
  end

  def test_should_have_a_name
    assert !@server.name.nil?
  end

end
