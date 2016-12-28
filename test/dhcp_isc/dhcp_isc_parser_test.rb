require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'
require 'dhcp_isc/isc_file_parser'

class DhcpIscParserTest < Test::Unit::TestCase
  DHCPD_CONFIG =<<END
# This is a comment.

subnet 192.168.122.0 netmask 255.255.255.0 {
  option routers 192.168.122.250; # This is an inline comment
  next-server 192.168.122.251;
}

subnet 192.168.123.0 netmask 255.255.255.192 {
  option subnet-mask 255.255.255.192;
  option routers 192.168.123.1;
  option domain-name-servers 192.168.123.1;
  option domain-name example.com;
  range 192.168.123.2 192.168.123.62;
}

subnet 192.168.124.0 netmask 255.255.255.0 {
  pool
  {
    range 192.168.124.200 192.168.124.254;
  }
  option domain-name foo.example.com;
  option routers 192.168.124.1, 192.168.124.2;
  option domain-name-servers 192.168.123.1, 192.168.122.250;
}

subnet 192.168.1.0 netmask 255.255.255.128 {
  class "pxeclients" {
    if option pxe-system-type = 00:02 {
      filename "xyz";
    }
  }
  # random stuff
  host hostinsidesubnet {
    server-name "hostinsidesubnet";
    hardware ethernet 00:18:dd:01:9e:2e;
    fixed-address 10.253.2.127;
  }
}

host test.example.com {
  hardware ethernet 00:11:bb:cc:dd:ee;
  fixed-address 192.168.122.1;
  supersede server.next-server = ac:17:23:1d;
}
END

  def setup
    @subnet_service =  Proxy::DHCP::SubnetService.initialized_instance
    @parser = ::Proxy::DHCP::ISC::FileParser.new(@subnet_service)
  end

  def test_subnet_matching_without_parameters_or_declarations
    assert "subnet 192.168.1.0 netmask 255.255.255.128 {}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_ip_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {option subnet-mask 255.255.255.192;}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_numerical_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {adaptive-lease-time-threshold 50;}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_timestamp_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {dynamic-bootp-lease-cutoff 5 2016/11/11 01:01:00;}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_string_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {filename \"filename\";}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_spaces_in_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 { option subnet-mask 255.255.255.192 ; }".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}}".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration_and_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}option subnet-mask 255.255.255.192;}".
      match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_mathing_with_spaces_in_declarations
    assert "subnet 192.168.1.0 netmask 255.255.255.128 { pool\n{ range abc ; } }".match(Proxy::DHCP::ISC::FileParser::SUBNET_BLOCK_REGEX)
  end

  def test_load_subnets_loads_managed_subnets
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal 4, subnets.size
  end

  def test_managed_subnets_options
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_not_nil subnets[0].options
    assert_not_nil subnets[1].options
    assert_not_nil subnets[2].options
    assert_equal Hash.new, subnets[3].options
  end

  def test_managed_subnets_network_addresses
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal "192.168.122.0", subnets[0].network
    assert_equal "192.168.123.0", subnets[1].network
    assert_equal "192.168.124.0", subnets[2].network
    assert_equal "192.168.1.0", subnets[3].network
  end

  def test_managed_subnets_netmask
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal "255.255.255.0", subnets[0].netmask
    assert_equal "255.255.255.192", subnets[1].netmask
    assert_equal "255.255.255.0", subnets[2].netmask
    assert_equal "255.255.255.128", subnets[3].netmask
  end

  def test_managed_subnets_router_addresses
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal ["192.168.122.250"], subnets[0].options[:routers]
    assert_equal nil, subnets[0].options[:routers][1]
    assert_equal ["192.168.123.1"], subnets[1].options[:routers]
    assert_equal ["192.168.124.1", "192.168.124.2"], subnets[2].options[:routers]
  end

  def test_managed_subnets_domain_name_servers
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal nil, subnets[0].options[:domain_name_servers]
    assert_equal ["192.168.123.1"], subnets[1].options[:domain_name_servers]
    assert_equal ["192.168.123.1", "192.168.122.250"], subnets[2].options[:domain_name_servers]
  end

  def test_managed_subnets_range
    subnets = @parser.parse_config_for_subnets(DHCPD_CONFIG)
    assert_equal nil, subnets[0].options[:range]
    assert_equal ["192.168.123.2", "192.168.123.62"], subnets[1].options[:range]
    assert_equal nil, subnets[2].options[:range]
  end

  def test_parse_config_and_leases
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    parsed = @parser.parse_config_and_leases_for_records(File.read("./test/fixtures/dhcp/dhcp.leases"))

    assert_equal 20, parsed.size

    deleted = parsed.select {|record| record.is_a?(::Proxy::DHCP::Reservation) && record.name == "deleted.example.com" }
    assert_equal [::Proxy::DHCP::Reservation, ::Proxy::DHCP::DeletedReservation], deleted.map(&:class)

    assert_nil parsed.find {|record| record.ip == "192.168.122.0" }
    assert_not_nil parsed.find {|record| record.respond_to?(:name) && record.name == "undeleted.example.com" }
    assert_not_nil parsed.find {|record| record.ip == "192.168.122.35"}
  end

  def test_convert_next_server_ip_from_hex
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    parsed = @parser.parse_config_and_leases_for_records(DHCPD_CONFIG)

    record = parsed.find {|r| r.is_a?(::Proxy::DHCP::Reservation) && r.name == "test.example.com" }
    assert_equal "172.23.35.29", record.nextServer
  end

  def test_get_ip_list_from_config_line
    assert_equal ["192.168.1.1"], @parser.get_ip_list_from_config_line("option foo-bar 192.168.1.1")
    assert_equal ["192.168.1.1", "192.168.20.10"], @parser.get_ip_list_from_config_line("option foo-bar 192.168.1.1,192.168.20.10")
    assert_equal ["192.168.1.1", "192.168.20.10", "192.168.130.100"], @parser.get_ip_list_from_config_line("option foo-bar 192.168.1.1, 192.168.20.10,192.168.130.100")
    assert_equal ["192.168.1.1", "192.168.20.10", "192.168.130.100", "10.1.1.1"], @parser.get_ip_list_from_config_line("option foo-bar 192.168.1.1, 192.168.20.10,192.168.130.100,      10.1.1.1")
  end

  def test_get_range_from_config_line
    assert_equal ["192.168.1.1", "192.168.1.254"], @parser.get_range_from_config_line("range 192.168.1.1 192.168.1.254")
    assert_equal ["192.168.10.1", "192.168.10.8"], @parser.get_range_from_config_line("range 192.168.10.1 192.168.10.8")
    assert_equal ["10.16.1.1", "10.16.1.254"], @parser.get_range_from_config_line("range 10.16.1.1 10.16.1.254")
  end
end
