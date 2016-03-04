require 'test_helper'
require 'dhcp_libvirt/dhcp_libvirt'
require 'dhcp_libvirt/dhcp_libvirt_main'
require 'dhcp_common/dependency_injection/dependencies'

class DhcpLibvirtProviderTest < Test::Unit::TestCase
  def setup
    fixture = <<XMLFIXTURE
<network>
  <name>default</name>
  <uuid>25703051-f5d4-4a31-80b7-37bbbc4d19e1</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:ed:a7:f7'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <host mac="00:16:3e:77:e2:ed" name="foo-1.example.com" ip="192.168.122.10" />
      <host mac="00:16:3e:77:e2:ee" name="foo-2.example.com" ip="192.168.122.11" />
    </dhcp>
  </ip>
</network>
XMLFIXTURE
    @json_leases = [{
        "ipaddr" => "192.168.122.22",
        "mac" => "52:54:00:13:05:12",
        "expirytime" => 1_455_723_598
    }]
    @libvirt_network = mock()
    @libvirt_network.stubs(:dump_xml).returns(fixture)
    @libvirt_network.stubs(:dhcp_leases).returns(@json_leases)
    @subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @service = Proxy::DHCP::SubnetService.new
    @subnet_store = @service.subnets = Proxy::MemoryStore.new
    @subject = ::Proxy::DHCP::Libvirt::Provider.new(:network => 'default', :libvirt_network => @libvirt_network, :name => "127.0.0.1")
    @subject.initialize_for_testing(:service => @service)
  end

  def test_default_settings
    ::Proxy::DHCP::Libvirt::Plugin.load_test_settings({})
    assert_equal 'default', Proxy::DHCP::Libvirt::Provider.new(:libvirt_network => @libvirt_network).network
  end

  def test_virsh_provider_initialization
    ::Proxy::DHCP::Libvirt::Plugin.load_test_settings(:network => 'some_network')
    assert_equal 'some_network', Proxy::DHCP::Libvirt::Provider.new(:libvirt_network => @libvirt_network).network
  end

  def test_libvirt_network_class
    assert_equal ::Proxy::DHCP::Libvirt::LibvirtDHCPNetwork, ::Proxy::DHCP::Libvirt::Provider.new.libvirt_network.class
  end

  def test_should_load_subnets
    @subject.load_subnets

    assert @service.find_subnet("192.168.122.0")
    assert_equal 1, @service.all_subnets.size
  end

  def test_should_load_subnet_data
    @subject.load_subnet_data(@subnet)

    assert @service.find_host_by_ip("192.168.122.0", "192.168.122.10")
    assert @service.find_host_by_ip("192.168.122.0", "192.168.122.11")
    assert @service.find_lease_by_ip("192.168.122.0", "192.168.122.22")
    assert @service.find_lease_by_mac("192.168.122.0", "52:54:00:13:05:12")
    assert_equal 2, @service.all_hosts.size
  end

  def test_should_add_record
    record_hash = { :name => "test.example.com", :ip => "192.168.122.95", :mac => "00:11:bb:cc:dd:ee", :network => "192.168.122.0/255.255.255.0", :subnet => @subnet }
    record = Proxy::DHCP::Reservation.new(record_hash)
    @service.add_subnet(@subnet)
    @subject.libvirt_network.expects(:add_dhcp_record).with(record)
    ::Proxy::DHCP::Server.any_instance.expects(:add_record).returns(record)
    @subject.add_record(hash_symbols_to_strings(record_hash))
  end

  def test_should_remove_record
    record =  Proxy::DHCP::Reservation.new(:name => "test.example.com", :ip => "192.168.122.10", :mac => "00:11:bb:cc:dd:ee", :subnet => @subnet)
    @service.add_subnet(@subnet)
    @service.add_host("192.168.122.0", record)
    @subject.libvirt_network.expects(:del_dhcp_record).with(record)
    @subject.del_record(@subnet, record)
  end
end
