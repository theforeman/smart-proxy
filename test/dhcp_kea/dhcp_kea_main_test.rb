require 'test_helper'
require 'dhcp_kea/dhcp_kea_main'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'

class DhcpKeaProviderTest < ::Test::Unit::TestCase
  def setup
    @subnet_service = Proxy::DHCP::SubnetService.initialized_instance
    @free_ips = mock('free_ips')
    @kea_client = mock('kea_client')

    @kea_client.stubs(:list_subnets).returns([
                                               {'subnet' => '192.168.1.0/24', 'id' => 1},
                                               {'subnet' => '10.0.0.0/8', 'id' => 2},
                                             ])

    @provider = Proxy::DHCP::Kea::Provider.new(@kea_client, @subnet_service, @free_ips, 60)
  end

  def test_initialize_loads_subnets
    assert_equal 2, @provider.subnets.count

    subnet = @provider.find_subnet('192.168.1.0/24')
    assert_not_nil subnet
    assert_equal 1, subnet.options[:kea_subnet_id]
  end

  def test_load_subnets_error_handling
    kea_client = mock('kea_client')
    kea_client.stubs(:list_subnets).raises(StandardError.new('Connection refused'))

    assert_raise(Proxy::DHCP::Error) do
      Proxy::DHCP::Kea::Provider.new(kea_client, @subnet_service, @free_ips)
    end
  end

  def test_add_record_success
    @provider.find_subnet('192.168.1.0/24')

    @kea_client.expects(:add_reservation).with(
      1,
      '192.168.1.50',
      'aa:bb:cc:dd:ee:ff',
      'test.example.com',
      has_entries(next_server: '192.168.1.1', boot_file_name: 'pxelinux.0')
    ).returns({})

    record = @provider.add_record(
      'hostname' => 'test.example.com',
      'ip' => '192.168.1.50',
      'mac' => 'aa:bb:cc:dd:ee:ff',
      'network' => '192.168.1.0/24',
      'nextServer' => '192.168.1.1',
      'filename' => 'pxelinux.0'
    )

    assert_not_nil record
    assert_equal '192.168.1.50', record.ip
    assert_equal 'aa:bb:cc:dd:ee:ff', record.mac
    assert_equal 'test.example.com', record.name
  end

  def test_add_record_without_pxe_options
    @kea_client.expects(:add_reservation).with(
      1,
      '192.168.1.51',
      'bb:cc:dd:ee:ff:00',
      'server2.example.com',
      {}
    ).returns({})

    record = @provider.add_record(
      'hostname' => 'server2.example.com',
      'ip' => '192.168.1.51',
      'mac' => 'bb:cc:dd:ee:ff:00',
      'network' => '192.168.1.0/24'
    )

    assert_not_nil record
  end

  def test_add_record_subnet_not_found
    assert_raise(Proxy::DHCP::Error) do
      @provider.add_record(
        'hostname' => 'test.example.com',
        'ip' => '172.16.0.50',
        'mac' => 'aa:bb:cc:dd:ee:ff',
        'network' => '172.16.0.0/24'
      )
    end
  end

  def test_add_record_kea_api_error
    @kea_client.expects(:add_reservation).raises(StandardError.new('KEA API error'))

    assert_raise(Proxy::DHCP::Error) do
      @provider.add_record(
        'hostname' => 'test.example.com',
        'ip' => '192.168.1.50',
        'mac' => 'aa:bb:cc:dd:ee:ff',
        'network' => '192.168.1.0/24'
      )
    end
  end

  def test_del_record_success
    @kea_client.stubs(:add_reservation).returns({})
    record = @provider.add_record(
      'hostname' => 'test.example.com',
      'ip' => '192.168.1.50',
      'mac' => 'aa:bb:cc:dd:ee:ff',
      'network' => '192.168.1.0/24'
    )

    @kea_client.expects(:delete_reservation_by_ip).with(1, '192.168.1.50').returns({})

    @provider.del_record(record)

    assert_nil @subnet_service.find_host_by_mac('192.168.1.0/24', 'aa:bb:cc:dd:ee:ff')
  end

  def test_del_record_subnet_not_found
    record = Proxy::DHCP::Reservation.new(
      'test.example.com',
      '172.16.0.50',
      'aa:bb:cc:dd:ee:ff',
      Proxy::DHCP::Subnet.new('172.16.0.0', '255.255.255.0')
    )

    assert_raise(Proxy::DHCP::Error) do
      @provider.del_record(record)
    end
  end

  def test_del_record_kea_api_error
    @kea_client.stubs(:add_reservation).returns({})
    record = @provider.add_record(
      'hostname' => 'test.example.com',
      'ip' => '192.168.1.50',
      'mac' => 'aa:bb:cc:dd:ee:ff',
      'network' => '192.168.1.0/24'
    )

    @kea_client.expects(:delete_reservation_by_ip).raises(StandardError.new('KEA API error'))

    assert_raise(Proxy::DHCP::Error) do
      @provider.del_record(record)
    end
  end

  def test_netmask_from_cidr
    provider = @provider

    assert_equal '255.255.255.0', provider.send(:netmask_from_cidr, '192.168.1.0/24')
    assert_equal '255.255.0.0', provider.send(:netmask_from_cidr, '10.0.0.0/16')
    assert_equal '255.0.0.0', provider.send(:netmask_from_cidr, '10.0.0.0/8')
    assert_equal '255.255.255.128', provider.send(:netmask_from_cidr, '192.168.1.0/25')
  end

  def test_load_subnet_options
    subnet = @provider.find_subnet('192.168.1.0/24')

    assert_nothing_raised do
      @provider.load_subnet_options(subnet)
    end
  end
end
