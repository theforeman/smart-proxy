require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_common/subnet_service'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/server'

class DHCPServerTest < Test::Unit::TestCase

  def setup
    @service = Proxy::DHCP::SubnetService.initialized_instance
    @server = Proxy::DHCP::Server.new("testcase", nil, @service)

    @subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0")
    @service.add_subnet(@subnet)

    @record = Proxy::DHCP::Reservation.new(:hostname => 'test', :name => 'test', :subnet => @subnet, :ip => "192.168.0.11", :mac => "aa:bb:cc:dd:ee:ff")
    @service.add_host(@subnet.network, @record)
  end

  def test_should_provide_subnets
    assert_respond_to @server, :subnets
  end

  def test_should_raise_exception_when_record_exists
    assert_raises Proxy::DHCP::AlreadyExists do
      @server.add_record('hostname' => 'test', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.11", 'mac' => "aa:bb:cc:dd:ee:ff")
    end
  end

  def test_should_raise_exception_when_address_in_use
    assert_raises Proxy::DHCP::Collision do
      @server.add_record('hostname' => 'test-1', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.11", 'mac' => "aa:bb:cc:dd:ee:ef")
    end
  end

  def test_not_should_raise_exception_when_address_with_related_mac_in_use
    record = Proxy::DHCP::Reservation.new(:hostname => 'example.com', :name => 'example.com-01', :subnet => @subnet, :ip => "192.168.0.15", :mac => "aa:bb:cc:dd:ee:ee")
    @service.add_host(@subnet.network, record)
    assert_nothing_raised do
      @server.add_record('hostname' => 'example.com', 'name' => 'example.com-02',
                         'network' => @subnet.network, 'ip' => "192.168.0.15", 'mac' => "aa:bb:cc:dd:ee:de",
                         'related_macs' => ['aa:bb:cc:dd:ee:ee'])
    end
  end

  def test_should_find_subnet_based_on_network
    assert_equal @subnet, @server.find_subnet("192.168.0.0")
  end

  def test_should_return_nil_when_no_subnet
    assert_nil @server.find_subnet("1.20.76.0")
  end

  def test_should_find_record_based_on_ip
    assert_equal @record, @server.find_record("192.168.0.0", "192.168.0.11")
  end

  def test_should_find_record_based_on_mac
    assert_equal @record, @server.find_record("192.168.0.0", "aa:bb:cc:dd:ee:ff")
  end

  def test_find_record_by_mac
    assert_equal @record, @server.find_record_by_mac("192.168.0.0", "aa:bb:cc:dd:ee:ff")
  end

  def test_find_records_by_ip
    assert_equal [@record], @server.find_records_by_ip("192.168.0.0", "192.168.0.11")
  end

  def test_ip_by_mac_address_and_range
    assert_equal @record.ip,
                 @server.ip_by_mac_address_and_range(@subnet, "aa:bb:cc:dd:ee:ff", "192.168.0.1", "192.168.0.15")
  end

  def test_ip_by_mac_address_and_range_should_return_nil_when_no_record_exists
    assert_nil @server.ip_by_mac_address_and_range(@subnet, "aa:aa:aa:aa:aa:aa", "192.168.0.1", "192.168.0.15")
  end

  def test_ip_by_mac_address_and_range_should_return_nil_when_range_ip_is_outside_range
    assert_nil @server.ip_by_mac_address_and_range(@subnet, "aa:bb:cc:dd:ee:ff", "192.168.0.100", "192.168.0.120")
  end

  def test_managed_subnet
    @server = Proxy::DHCP::Server.new("testcase", ['192.168.1.0/255.255.255.0', '192.168.2.0/255.255.255.0'], nil)
    assert @server.managed_subnet?('192.168.1.0/255.255.255.0')
    assert @server.managed_subnet?('192.168.2.0/255.255.255.0')
    assert !@server.managed_subnet?('192.168.3.0/255.255.255.0')
  end

  def test_managed_subnet_should_return_true_when_setting_is_undefined
    ::Proxy::DhcpPlugin.load_test_settings({})
    assert @server.managed_subnet?('192.168.1.0/255.255.255.0')
  end

  def test_should_have_a_name
    assert !@server.name.nil?
  end

  def test_del_records_by_ip
    @server.expects(:del_record).with(@subnet, @record).once
    @server.del_records_by_ip(@subnet, '192.168.0.11')
  end

  def test_del_record_by_mac
    @server.expects(:del_record).with(@subnet, @record).once
    @server.del_record_by_mac(@subnet, 'aa:bb:cc:dd:ee:ff')
  end
end
