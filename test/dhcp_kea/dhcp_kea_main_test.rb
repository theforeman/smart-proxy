require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/free_ips'
require 'dhcp_kea/kea_api_client'
require 'dhcp_kea/dhcp_kea_main'

class DhcpKeaProviderTest < Test::Unit::TestCase
  SUBNETS = [
    {'id' => 1, 'subnet' => '192.168.1.0/24',
     'pools' => [{'pool' => '192.168.1.100 - 192.168.1.200'}],
     'option-data' => [{'name' => 'routers', 'data' => '192.168.1.1'},
                       {'name' => 'domain-name-servers', 'data' => '192.168.1.2, 192.168.1.3'},
                       {'name' => 'domain-name', 'data' => 'example.com'}]},
    {'id' => 7, 'subnet' => '10.0.0.0/22', 'pools' => [{'pool' => '10.0.1.0/24'}]},
  ].freeze

  HOST = {'subnet-id' => 1, 'ip-address' => '192.168.1.10', 'hw-address' => 'aa:bb:cc:dd:ee:01', 'hostname' => 'host1.example.com',
          'next-server' => '192.168.1.5', 'boot-file-name' => 'pxelinux.0'}.freeze
  LEASE = {'subnet-id' => 1, 'ip-address' => '192.168.1.150', 'hw-address' => 'aa:bb:cc:dd:ee:99', 'hostname' => 'dyn1',
           'cltt' => 1_700_000_000, 'valid-lft' => 3600, 'state' => 0}.freeze

  def setup
    @client = Proxy::DHCP::Kea::KeaApiClient.new('http://127.0.0.1:8000/')
    @client.stubs(:subnets).returns(SUBNETS)
    @provider = Proxy::DHCP::Kea::Provider.new(@client, nil, Proxy::DHCP::FreeIps.new)
  end

  def test_subnets
    assert_equal([['192.168.1.0', '255.255.255.0'], ['10.0.0.0', '255.255.252.0']], @provider.subnets.map { |s| [s.network, s.netmask] })
  end

  def test_subnet_options
    subnet = @provider.find_subnet('192.168.1.0')
    assert_equal ['192.168.1.1'], subnet.options[:routers]
    assert_equal ['192.168.1.2', '192.168.1.3'], subnet.options[:domain_name_servers]
    assert_equal 'example.com', subnet.options[:domain_name]
    assert_equal ['192.168.1.100', '192.168.1.200'], subnet.options[:range]
  end

  def test_subnet_with_cidr_pool
    assert_equal ['10.0.1.0', '10.0.1.255'], @provider.find_subnet('10.0.0.0').options[:range]
  end

  def test_kea_subnet_id_not_exposed_in_options
    assert_not_include @provider.find_subnet('192.168.1.0').options.keys, :kea_subnet_id
  end

  def test_subnets_loaded_once_per_provider
    @client.expects(:subnets).once.returns(SUBNETS)
    provider = Proxy::DHCP::Kea::Provider.new(@client, nil, Proxy::DHCP::FreeIps.new)
    provider.subnets
    provider.find_subnet('192.168.1.0')
  end

  def test_managed_subnets
    provider = Proxy::DHCP::Kea::Provider.new(@client, ['10.0.0.0/255.255.252.0'], Proxy::DHCP::FreeIps.new)
    assert_equal ['10.0.0.0'], provider.subnets.map(&:network)
  end

  def test_unknown_subnet
    assert_raises(Proxy::DHCP::SubnetNotFound) { @provider.all_hosts('172.16.0.0') }
  end

  def test_all_hosts
    @client.expects(:reservations).with(1).returns([HOST])
    host = @provider.all_hosts('192.168.1.0').first
    assert_equal ['host1.example.com', '192.168.1.10', 'aa:bb:cc:dd:ee:01', '192.168.1.5', 'pxelinux.0'],
                 [host.name, host.ip, host.mac, host.nextServer, host.filename]
  end

  def test_all_hosts_ignores_empty_boot_fields
    @client.expects(:reservations).with(1).returns([HOST.merge('next-server' => '0.0.0.0', 'boot-file-name' => '')])
    host = @provider.all_hosts('192.168.1.0').first
    assert_nil host.options[:nextServer]
    assert_nil host.options[:filename]
  end

  def test_all_leases
    @client.expects(:leases).with(1).returns([LEASE, LEASE.merge('ip-address' => '192.168.1.151', 'state' => 2)])
    leases = @provider.all_leases('192.168.1.0')
    assert_equal ['192.168.1.150'], leases.map(&:ip)
    assert_equal 'active', leases.first.state
    assert_equal Time.at(1_700_000_000).utc, leases.first.starts
    assert_equal Time.at(1_700_003_600).utc, leases.first.ends
  end

  def test_find_records_by_ip_prefers_reservation
    @client.expects(:reservation_by_ip).with(1, '192.168.1.10').returns(HOST)
    @client.expects(:lease_by_ip).never
    assert_kind_of Proxy::DHCP::Reservation, @provider.find_records_by_ip('192.168.1.0', '192.168.1.10').first
  end

  def test_find_records_by_ip_falls_back_to_lease
    @client.expects(:reservation_by_ip).with(1, '192.168.1.150').returns(nil)
    @client.expects(:lease_by_ip).with('192.168.1.150').returns(LEASE)
    assert_kind_of Proxy::DHCP::Lease, @provider.find_records_by_ip('192.168.1.0', '192.168.1.150').first
  end

  def test_find_records_by_ip_ignores_lease_in_other_subnet
    @client.expects(:reservation_by_ip).returns(nil)
    @client.expects(:lease_by_ip).returns(LEASE.merge('subnet-id' => 7))
    assert_empty @provider.find_records_by_ip('192.168.1.0', '192.168.1.150')
  end

  def test_find_record_by_mac
    @client.expects(:reservation_by_mac).with(1, 'aa:bb:cc:dd:ee:99').returns(nil)
    @client.expects(:lease_by_mac).with(1, 'aa:bb:cc:dd:ee:99').returns(LEASE)
    assert_equal '192.168.1.150', @provider.find_record_by_mac('192.168.1.0', 'aa:bb:cc:dd:ee:99').ip
  end

  def test_add_record
    @client.stubs(:reservation_by_ip).returns(nil)
    @client.stubs(:reservation_by_mac).returns(nil)
    @client.expects(:add_reservation).with('subnet-id' => 1, 'ip-address' => '192.168.1.10', 'hw-address' => 'aa:bb:cc:dd:ee:01',
                                           'hostname' => 'host1.example.com', 'next-server' => '192.168.1.5', 'boot-file-name' => 'pxelinux.0')

    record = @provider.add_record('hostname' => 'host1.example.com', 'ip' => '192.168.1.10', 'mac' => 'AA:BB:CC:DD:EE:01',
                                  'network' => '192.168.1.0', 'nextServer' => '192.168.1.5', 'filename' => 'pxelinux.0')
    assert_equal '192.168.1.10', record.ip
  end

  def test_add_record_resolves_next_server_hostname
    @client.stubs(:reservation_by_ip).returns(nil)
    @client.stubs(:reservation_by_mac).returns(nil)
    resolver = mock('resolver')
    resolver.expects(:getresource).with('tftp.example.com', Resolv::DNS::Resource::IN::A).returns(Resolv::DNS::Resource::IN::A.new('192.168.1.6'))
    @provider.stubs(:dns_resolv).returns(resolver)
    @client.expects(:add_reservation).with(has_entry('next-server', '192.168.1.6'))

    @provider.add_record('hostname' => 'h', 'ip' => '192.168.1.10', 'mac' => 'aa:bb:cc:dd:ee:01', 'network' => '192.168.1.0', 'nextServer' => 'tftp.example.com')
  end

  def test_add_existing_record
    @client.stubs(:reservation_by_ip).returns(HOST)
    @client.stubs(:reservation_by_mac).returns(HOST)
    @client.expects(:add_reservation).never
    assert_raises(Proxy::DHCP::AlreadyExists) do
      @provider.add_record('hostname' => 'host1.example.com', 'ip' => '192.168.1.10', 'mac' => 'aa:bb:cc:dd:ee:01', 'network' => '192.168.1.0',
                           'nextServer' => '192.168.1.5', 'filename' => 'pxelinux.0')
    end
  end

  def test_add_conflicting_record
    @client.stubs(:reservation_by_ip).returns(HOST)
    @client.stubs(:reservation_by_mac).returns(nil)
    @client.expects(:add_reservation).never
    assert_raises(Proxy::DHCP::Collision) do
      @provider.add_record('hostname' => 'other', 'ip' => '192.168.1.10', 'mac' => 'aa:bb:cc:dd:ee:02', 'network' => '192.168.1.0')
    end
  end

  def test_add_record_duplicate_in_database
    @client.stubs(:reservation_by_ip).returns(nil)
    @client.stubs(:reservation_by_mac).returns(nil)
    @client.expects(:add_reservation).raises(Proxy::DHCP::Error, "Kea command 'reservation-add' failed: Database duplicate entry error")
    assert_raises(Proxy::DHCP::Collision) do
      @provider.add_record('hostname' => 'h', 'ip' => '192.168.1.10', 'mac' => 'aa:bb:cc:dd:ee:01', 'network' => '192.168.1.0')
    end
  end

  def test_del_reservation
    @client.expects(:delete_reservation).with(1, 'aa:bb:cc:dd:ee:01')
    @client.expects(:delete_lease).never
    subnet = @provider.find_subnet('192.168.1.0')
    @provider.del_record(Proxy::DHCP::Reservation.new('h', '192.168.1.10', 'aa:bb:cc:dd:ee:01', subnet))
  end

  def test_del_lease
    @client.expects(:delete_lease).with('192.168.1.150')
    @client.expects(:delete_reservation).never
    subnet = @provider.find_subnet('192.168.1.0')
    @provider.del_record(Proxy::DHCP::Lease.new(nil, '192.168.1.150', 'aa:bb:cc:dd:ee:99', subnet, nil, nil, nil))
  end

  def test_unused_ip_skips_used_addresses
    ::Proxy::DhcpPlugin.settings.stubs(:ping_free_ip).returns(false)
    @client.stubs(:reservations).returns([HOST.merge('ip-address' => '192.168.1.100')])
    @client.stubs(:leases).returns([LEASE.merge('ip-address' => '192.168.1.101')])
    assert_equal '192.168.1.102', @provider.unused_ip('192.168.1.0', nil, '192.168.1.100', '192.168.1.102')
  end

  def test_unused_ip_reuses_address_of_known_mac
    @client.expects(:reservation_by_mac).with(1, 'aa:bb:cc:dd:ee:01').returns(HOST)
    assert_equal '192.168.1.10', @provider.unused_ip('192.168.1.0', 'aa:bb:cc:dd:ee:01', '192.168.1.1', '192.168.1.20')
  end
end
