require 'test_helper'
require 'ostruct'
require 'dns_libvirt/libvirt_dns_network'

class LibvirtDNSNetworkTest < Test::Unit::TestCase
  def setup
    @connection = mock()
    @network = mock()
    @connection.stubs(:lookup_network_by_name).returns(@network)
    ::Libvirt.stubs(:open).returns(@connection)
    @subject = ::Proxy::Dns::Libvirt::LibvirtDNSNetwork.new
    @subject.stubs(:find_network).returns(@network)
    @network.stubs(:xml_desc).returns('')
    @network.stubs(:dhcp_leases).returns([])
    @flags = ::Libvirt::Network::NETWORK_UPDATE_AFFECT_LIVE | ::Libvirt::Network::NETWORK_UPDATE_AFFECT_CONFIG
  end

  def test_add_dns_a_record
    record = OpenStruct.new(
      "fqdn" => "test.example.com",
      "ip" => "192.168.122.10")
    xml = "<host ip=\"#{record.ip}\"><hostname>#{record.fqdn}</hostname></host>"
    @network.expects(:update).with(::Libvirt::Network::UPDATE_COMMAND_ADD_LAST, ::Libvirt::Network::NETWORK_SECTION_DNS_HOST, -1, xml, @flags).returns(true)
    assert_equal true, @subject.add_dns_a_record(record.fqdn, record.ip)
  end

  def test_del_dns_a_record
    record = OpenStruct.new(
      "fqdn" => "test.example.com",
      "ip" => "192.168.122.10")
    xml = "<host ip=\"#{record.ip}\"><hostname>#{record.fqdn}</hostname></host>"
    @network.expects(:update).with(::Libvirt::Network::UPDATE_COMMAND_DELETE, ::Libvirt::Network::NETWORK_SECTION_DNS_HOST, -1, xml, @flags).returns(true)
    assert_equal true, @subject.del_dns_a_record(record.fqdn, record.ip)
  end
end
