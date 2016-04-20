require 'test_helper'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_isc/leases_file'
require 'tempfile'

class LeasesFileTest < Test::Unit::TestCase
  def setup
    @parser = Object.new
    @leases_file = Tempfile.new('test_config_file')
    @leases = ::Proxy::DHCP::ISC::LeasesFile.new(@leases_file.path, @parser)
  end

  def test_hosts_and_leases_should_use_parser
    record_to_return = Proxy::DHCP::Reservation.new(
        :name => 'a_test', :ip => '192.168.42.1',
        :mac => '00:01:02:03:04:05',
        :subnet => ::Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0'))
    @parser.expects(:parse_config_and_leases_for_records).returns([record_to_return])

    assert_equal [record_to_return], @leases.hosts_and_leases
  end

  def test_close_should_set_file_descriptor_to_nil
    @parser.stubs(:parse_config_and_leases_for_records).returns([])
    @leases.hosts_and_leases
    assert !@leases.fd.nil?

    @leases.close
    assert @leases.fd.nil?
  end
end
