require 'test_helper'
require 'ostruct'
require 'dhcp_libvirt/libvirt_dhcp_network'

class LibvirtDHCPNetworkTest < Test::Unit::TestCase
  def setup
    @connection = mock()
    @network = mock()
    @connection.stubs(:lookup_network_by_name).returns(@network)
    ::Libvirt.stubs(:open).returns(@connection)
    @subject = ::Proxy::DHCP::Libvirt::LibvirtDHCPNetwork.new
    @subject.stubs(:find_network).returns(@network)
    @network.stubs(:xml_desc).returns('')
    @network.stubs(:dhcp_leases).returns([])
    @flags = ::Libvirt::Network::NETWORK_UPDATE_AFFECT_LIVE | ::Libvirt::Network::NETWORK_UPDATE_AFFECT_CONFIG
  end

  def test_dump_xml
    a_xml = '<xml></xml>'
    @network.expects(:xml_desc).returns(a_xml)
    assert_equal a_xml, @subject.dump_xml
  end

  def test_dhcp_leases
    leases = [:a, :b]
    @network.expects(:dhcp_leases).returns(leases)
    assert_equal leases, @subject.dhcp_leases
  end

  def test_add_dhcp_record
    record = OpenStruct.new(
      "name" => "test.example.com",
      "ip" => "192.168.122.10",
      "mac" => "00:11:bb:cc:dd:ee")
    xml = "<host mac=\"#{record.mac}\" ip=\"#{record.ip}\" name=\"#{record.name}\"/>"
    @network.expects(:update).with(::Libvirt::Network::UPDATE_COMMAND_ADD_LAST, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, -1, xml, @flags).returns(true)
    assert_equal true, @subject.add_dhcp_record(record)
  end

  def test_del_dhcp_record
    record = OpenStruct.new(
      "name" => "test.example.com",
      "ip" => "192.168.122.10",
      "mac" => "00:11:bb:cc:dd:ee")
    # record = Proxy::DHCP::Reservation.new(:name => "test.example.com", :ip => "192.168.122.10", :mac => "00:11:bb:cc:dd:ee", :subnet => subnet)
    xml = "<host mac=\"#{record.mac}\" ip=\"#{record.ip}\" name=\"#{record.name}\"/>"
    @network.expects(:update).with(::Libvirt::Network::UPDATE_COMMAND_DELETE, ::Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST, -1, xml, @flags).returns(true)
    assert_equal true, @subject.del_dhcp_record(record)
  end
end
