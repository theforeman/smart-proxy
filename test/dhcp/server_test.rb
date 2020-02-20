require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_common/subnet_service'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/server'

class DHCPServerTest < Test::Unit::TestCase
  def setup
    @service = Proxy::DHCP::SubnetService.initialized_instance
    @free_ips = Object.new
    @server = Proxy::DHCP::Server.new("testcase", nil, @service, @free_ips)

    @subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0")
    @service.add_subnet(@subnet)

    @record = Proxy::DHCP::Reservation.new('test', "192.168.0.11", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test', :deleteable => true)
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

  def test_should_detect_ip_address_collision_with_a_reservation
    assert_raises Proxy::DHCP::Collision do
      @server.add_record('hostname' => 'test-1', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.11", 'mac' => "aa:bb:cc:dd:ee:ef")
    end
  end

  def test_should_detect_mac_address_collision_with_a_reservation
    assert_raises Proxy::DHCP::Collision do
      @server.add_record('hostname' => 'test-1', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.10", 'mac' => "aa:bb:cc:dd:ee:ff")
    end
  end

  def test_should_ignore_ip_address_collision_with_a_lease
    @service.add_lease(@subnet.network, ::Proxy::DHCP::Lease.new('test-2', "192.168.0.12", "00:11:22:33:44:55", @subnet, nil, nil, nil))
    assert_nothing_raised do
      @server.add_record('hostname' => 'test-1', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.12", 'mac' => "aa:bb:cc:dd:ee:ef")
    end
  end

  def test_should_ignore_mac_address_collision_with_a_lease
    @service.add_lease(@subnet.network, ::Proxy::DHCP::Lease.new('test-2', "192.168.0.13", "00:11:22:33:44:55", @subnet, nil, nil, nil))
    assert_nothing_raised Proxy::DHCP::Collision do
      @server.add_record('hostname' => 'test-1', 'name' => 'test', 'network' => @subnet.network, 'ip' => "192.168.0.12", 'mac' => "00:11:22:33:44:55")
    end
  end

  def test_not_should_raise_exception_when_address_with_related_mac_in_use
    record = Proxy::DHCP::Reservation.new('example.com-01', "192.168.0.15", "aa:bb:cc:dd:ee:ee", @subnet, :hostname => 'example.com')
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
                 @server.find_ip_by_mac_address_and_range(@subnet, "aa:bb:cc:dd:ee:ff", "192.168.0.1", "192.168.0.15")
  end

  def test_ip_by_mac_address_and_range_should_return_nil_when_no_record_exists
    assert_nil @server.find_ip_by_mac_address_and_range(@subnet, "aa:aa:aa:aa:aa:aa", "192.168.0.1", "192.168.0.15")
  end

  def test_ip_by_mac_address_and_range_should_return_nil_when_range_ip_is_outside_range
    assert_nil @server.find_ip_by_mac_address_and_range(@subnet, "aa:bb:cc:dd:ee:ff", "192.168.0.100", "192.168.0.120")
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
    @server.expects(:del_record).with(@record).once
    @server.del_records_by_ip(@subnet.network, '192.168.0.11')
  end

  def test_del_record_by_mac
    @server.expects(:del_record).with(@record).once
    @server.del_record_by_mac(@subnet.network, 'aa:bb:cc:dd:ee:ff')
  end

  def test_unused_ip
    @free_ips.expects(:find_free_ip)
             .with("192.168.0.1", "192.168.0.10", @service.all_hosts("192.168.0.0"))
             .returns(nil)
    @server.unused_ip("192.168.0.0", nil, "192.168.0.1", "192.168.0.10")
  end

  def test_unused_ip_with_mac_address_specified
    assert_equal "192.168.0.11",
                 @server.unused_ip("192.168.0.0", "aa:bb:cc:dd:ee:ff", "192.168.0.1", "192.168.0.20")
  end

  def test_clean_up_add_record_parameters
    expected_ip = "192.168.33.100"
    expected_mac = "01:02:03:04:05:06"
    expected_subnet = "192.168.33.0"

    _, ip, mac, subnet, _ = @server.clean_up_add_record_parameters("ip" => expected_ip, "mac" => expected_mac,
                                                                   "network" => expected_subnet)

    assert_equal expected_ip, ip
    assert_equal expected_mac, mac
    assert_equal expected_subnet, subnet
  end

  def test_clean_up_add_record_parameters_ignores_subnet_key
    _, _, _, subnet, _ = @server.clean_up_add_record_parameters("subnet" => "192.168.33.0")
    assert_nil subnet
  end

  def test_clean_up_add_record_parameters_uses_hostname_key_to_create_hostname_option
    expected_hostname = "thisishostname"
    expected_name = "thisisname"
    name, _, _, _, actual_options = @server.clean_up_add_record_parameters("hostname" => expected_hostname,
                                                                           "name" => expected_name)

    assert_equal expected_name, name
    assert_equal({:hostname => expected_hostname}, actual_options)
  end

  def test_clean_up_add_record_parameters_uses_name_key_to_create_hostname_option
    expected_hostname = "testing"
    name, _, _, _, actual_options = @server.clean_up_add_record_parameters("name" => expected_hostname)

    assert_equal expected_hostname, name
    assert_equal({:hostname => expected_hostname}, actual_options)
  end

  def test_clean_up_add_record_parameters_converts_string_keys_to_symbols
    _, _, _, _, actual_options = @server.clean_up_add_record_parameters("a" => 1, "b" => 2)
    assert_equal({:a => 1, :b => 2, :hostname => nil}, actual_options)
  end
end
