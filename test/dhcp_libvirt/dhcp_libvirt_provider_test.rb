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
    @subject = ::Proxy::DHCP::Libvirt::Provider.new('default', @libvirt_network, @service, nil)
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
    record = Proxy::DHCP::Reservation.new("test.example.com", "192.168.122.10", "00:11:bb:cc:dd:ee", @subnet)
    @service.add_subnet(@subnet)
    @service.add_host("192.168.122.0", record)
    @subject.libvirt_network.expects(:del_dhcp_record).with(record)
    @subject.del_record(record)
  end

  def test_validate_ip
    assert_nothing_raised do
      @subject.validate_supported_address("192.168.122.0", "192.168.122.0", "192.168.122.0", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_not_validate_ipv6
    assert_raises Proxy::Validations::InvalidIPAddress do
      @subject.validate_supported_address("192.168.122.0", "192.168.122.0", "2001:db8::8:800:200c:417a", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_raise_exception_for_invalid_ip
    assert_raises Proxy::Validations::InvalidIPAddress do
      @subject.validate_supported_address("192.168.122.0", "192.168.122.0", "266.168.122.0", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_raise_exception_for_invalid_ip_single
    assert_raises Proxy::Validations::InvalidIPAddress do
      @subject.validate_supported_address("266.168.122.0")
    end
  end
end
