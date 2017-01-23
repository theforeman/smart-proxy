require 'test_helper'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_isc/configuration_file'
require 'tempfile'

class IscConfigurationFileTest < Test::Unit::TestCase
  def setup
    @parser = Object.new
    @config_file = Tempfile.new('test_config_file')
    @config = ::Proxy::DHCP::ISC::ConfigurationFile.new(@config_file.path, @parser)
  end

  def test_read_config_file_respects_includes
    whole_config = @config.read(StringIO.new("# Test that the ISC DHCP config file parser includes files\ninclude \"test/fixtures/dhcp/dhcp_subnets.conf\";"))
    assert whole_config.include?("subnet 192.168.122.0 netmask 255.255.255.0")
    assert whole_config.include?("subnet 192.168.124.0 netmask 255.255.255.0")
    assert whole_config.include?("host test.example.com")
  end

  def test_read_config_file_should_raise_error_if_included_file_isn_not_readable
    assert_raises(RuntimeError) { @config.read(StringIO.new("include \"non_existent_config\";")) }
  end

  def test_load_subnets
    subnet_to_return = ::Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0')
    @parser.expects(:parse_config_for_subnets).returns([subnet_to_return])

    assert_equal [subnet_to_return], @config.subnets
  end

  def test_hosts_and_leases_should_use_parser
    record_to_return = Proxy::DHCP::Reservation.new(
        'a_test', '192.168.42.1', '00:01:02:03:04:05',
        ::Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0'))
    @parser.expects(:parse_config_and_leases_for_records).returns([record_to_return])

    assert_equal [record_to_return], @config.hosts_and_leases
  end
end
