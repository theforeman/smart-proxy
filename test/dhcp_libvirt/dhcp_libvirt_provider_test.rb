require 'test_helper'
require 'dhcp_common/server'
require 'dhcp_common/subnet_service'
require 'dhcp_libvirt/dhcp_libvirt'
require 'dhcp_libvirt/dhcp_libvirt_main'

class DhcpLibvirtProviderTest < Test::Unit::TestCase
  def setup
    @libvirt_network = mock()
    @subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_store = {}
    @service = Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new, Proxy::MemoryStore.new, @subnet_store)
    @subject = ::Proxy::DHCP::Libvirt::Provider.new('default', @libvirt_network, @service)
  end

  def test_should_add_record
    record_hash = { :name => "test.example.com", :ip => "192.168.122.95", :mac => "00:11:bb:cc:dd:ee", :network => "192.168.122.0/255.255.255.0", :subnet => @subnet }
    record = Proxy::DHCP::Reservation.new("test.example.com", "192.168.122.95", "00:11:bb:cc:dd:ee", @subnet)
    @service.add_subnet(@subnet)
    @subject.libvirt_network.expects(:add_dhcp_record).with(record)
    ::Proxy::DHCP::Server.any_instance.expects(:add_record).returns(record)
    @subject.add_record(hash_symbols_to_strings(record_hash))
  end

  def test_should_remove_record
    record =  Proxy::DHCP::Reservation.new("test.example.com", "192.168.122.10", "00:11:bb:cc:dd:ee", @subnet)
    @service.add_subnet(@subnet)
    @service.add_host("192.168.122.0", record)
    @subject.libvirt_network.expects(:del_dhcp_record).with(record)
    @subject.del_record(record)
  end
end
