require 'test_helper'
require 'dhcp_common/subnet_service'
require 'dhcp_libvirt/subnet_service_initializer'

class SubnetServiceInitializerTest < Test::Unit::TestCase
  def setup
    @network_xml = <<XMLFIXTURE
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
    @subnet_store = {}
    @service = Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new, Proxy::MemoryStore.new, @subnet_store)
    @service_inititalizer = ::Proxy::DHCP::Libvirt::SubnetServiceInitializer.new(@libvirt_network)
  end

  def test_should_load_subnets
    @libvirt_network.expects(:dump_xml).twice.returns(@network_xml)
    @libvirt_network.stubs(:dhcp_leases).returns(@json_leases)
    service = @service_inititalizer.initialized_subnet_service(@service)

    assert service.find_subnet("192.168.122.0")
    assert_equal 1, service.all_subnets.size
  end

  def test_should_load_subnet_data
    @libvirt_network.expects(:dump_xml).twice.returns(@network_xml)
    @libvirt_network.expects(:dhcp_leases).returns(@json_leases)
    service = @service_inititalizer.initialized_subnet_service(@service)

    assert service.find_hosts_by_ip("192.168.122.0", "192.168.122.10")
    assert service.find_hosts_by_ip("192.168.122.0", "192.168.122.11")
    assert service.find_lease_by_ip("192.168.122.0", "192.168.122.22")
    assert service.find_lease_by_mac("192.168.122.0", "52:54:00:13:05:12")
    assert_equal 2, service.all_hosts.size
  end
end
