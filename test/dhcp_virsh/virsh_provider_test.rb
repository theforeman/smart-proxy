require 'test_helper'
require 'dhcp_virsh/dhcp_virsh'
require 'dhcp_virsh/dhcp_virsh_main'
require 'dhcp_common/dependency_injection/dependencies'

class VirshProviderTest < Test::Unit::TestCase
  def setup
    @service = Proxy::DHCP::SubnetService.new
    @subnet_store = @service.subnets = Proxy::MemoryStore.new
    @server = ::Proxy::DHCP::Virsh::Provider.new.initialize_for_testing(:network => 'default',
                                                                        :name => "127.0.0.1", :service => @service)
    @dump_xml = <<EODUMPXML
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
EODUMPXML

    @json_leases = [{
        "ip-address" => "192.168.122.22",
        "mac-address" => "52:54:00:13:05:12",
        "client-id" => "01:52:54:00:13:05:12",
        "expiry-time" => 1_455_723_598
    }]
  end

  def test_default_settings
    assert_equal 'default', Proxy::DHCP::Virsh::Provider.new.network
    assert_equal '/var/lib/libvirt/dnsmasq/virbr0.status', Proxy::DHCP::Virsh::Provider.new.leases
  end

  def test_virsh_provider_initialization
    ::Proxy::DHCP::Virsh::Plugin.load_test_settings(:network => 'some_network', :leases => 'leases.txt')
    assert_equal 'some_network', Proxy::DHCP::Virsh::Provider.new.network
    assert_equal 'leases.txt', Proxy::DHCP::Virsh::Provider.new.leases
  end

  def test_should_load_subnets
    @server.expects(:dump_xml).returns(@dump_xml)
    @server.load_subnets

    assert @service.find_subnet("192.168.122.0")
    assert_equal 1, @service.all_subnets.size
  end

  def test_should_load_subnet_data
    @server.expects(:dump_xml).returns(@dump_xml)
    @server.expects(:parse_json_for_dhcp_leases).returns(@json_leases)
    @server.load_subnet_data(Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0"))

    assert @service.find_host_by_ip("192.168.122.0", "192.168.122.10")
    assert @service.find_host_by_ip("192.168.122.0", "192.168.122.11")
    assert @service.find_lease_by_ip("192.168.122.0", "192.168.122.22")
    assert @service.find_lease_by_mac("192.168.122.0", "52:54:00:13:05:12")
    assert_equal 2, @service.all_hosts.size
  end

  def test_should_add_record
    to_add = { "hostname" => "test.example.com", "ip" => "192.168.122.10",
               "mac" => "00:11:bb:cc:dd:ee", "network" => "192.168.122.0/255.255.255.0" }

    @service.add_subnet(Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0"))
    @server.expects(:virsh_update_dhcp).with('add-last', to_add['mac'], to_add['ip'], to_add['hostname'])
    @server.add_record(to_add)
  end

  def test_should_remove_record
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @service.add_subnet(subnet)
    to_delete =  Proxy::DHCP::Reservation.new(:name => "test.example.com", :ip => "192.168.122.10",
                                              :mac => "00:11:bb:cc:dd:ee", :subnet => subnet)
    @service.add_host("192.168.122.0", to_delete)
    @server.expects(:virsh_update_dhcp).with('delete', to_delete.mac, to_delete.ip, to_delete.hostname)

    @server.del_record("192.168.122.0", to_delete)
  end
end
