require 'test_helper'
require 'dhcp/sparc_attrs'
require 'json'
require 'dhcp/dhcp'
require 'dhcp/providers/server/isc'

class ServerIscTest < Test::Unit::TestCase
  class OMIO
    attr_reader :input_commands

    def initialize
      @input_commands = []
    end

    def puts str
      @input_commands << str
    end
  end

  include SparcAttrs

  def setup
    Proxy::DhcpPlugin.load_test_settings(
      :enabled => true,
      :dhcp_vendor => 'isc',
      :dhcp_omapi_port => 999,
      :dhcp_config => './test/fixtures/dhcp/dhcp.conf',
      :dhcp_leases => './test/fixtures/dhcp/dhcp.leases',
      :dhcp_subnets => '192.168.122.0/255.255.255.0')

    @subnet_service = Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                                     Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                                     Proxy::MemoryStore.new, Proxy::MemoryStore.new)
    @dhcp = Proxy::DHCP::Server::ISC.new(
        :name => '192.168.122.1', :config => './test/fixtures/dhcp/dhcp.conf',
        :leases => './test/fixtures/dhcp/dhcp.leases',
        :service => @subnet_service)
  end

  def test_omcmd_server_connect
    srv = Proxy::DHCP::ISC.new :name => '1.2.3.4', :config => './test/fixtures/dhcp/dhcp.conf', :leases => './test/fixtures/dhcp/dhcp.leases'
    srv.stubs(:which).returns('fakeshell')
    omio = OMIO.new
    IO.expects(:popen).with("/bin/sh -c 'fakeshell 2>&1'", "r+").returns(omio)
    srv.send(:omcmd, 'connect')
    assert_equal "port 999", omio.input_commands[1]
    assert_equal "server 1.2.3.4", omio.input_commands[0]
  end

  def test_sparc_host_quirks
    assert_equal [], @dhcp.send(:solaris_options_statements, {})

    assert_equal [
      %q{option SUNW.JumpStart-server \"192.168.122.24:/Solaris/jumpstart\";},
      %q{option SUNW.install-path \"/Solaris/install/Solaris_5.10_sparc_hw0811\";},
      %q{option SUNW.install-server-hostname \"itgsyddev807.macbank\";},
      %q{option SUNW.install-server-ip-address 192.168.122.24;},
      %q{option SUNW.root-path-name \"/Solaris/install/Solaris_5.10_sparc_hw0811/Solaris_10/Tools/Boot\";},
      %q{option SUNW.root-server-hostname \"itgsyddev807.macbank\";},
      %q{option SUNW.root-server-ip-address 192.168.122.24;},
      %q{option SUNW.sysid-config-file-server \"192.168.122.24:/Solaris/jumpstart/sysidcfg/sysidcfg_primary\";},
      %q{vendor-option-space SUNW;}
    ], @dhcp.send(:solaris_options_statements, sparc_attrs).sort
  end

  def test_ztp_quirks
    assert_equal [], @dhcp.send(:ztp_options_statements, {})
    assert_equal [], @dhcp.send(:ztp_options_statements, :filename => 'foo.cfg')

    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";'],
                 @dhcp.send(:ztp_options_statements, :filename => 'ztp.cfg', :nextServer => '192.168.122.1')
  end

  def test_poap_quirks
    assert_equal [], @dhcp.send(:poap_options_statements, {})
    assert_equal [], @dhcp.send(:poap_options_statements, :filename => 'foo.cfg')

    assert_equal ['option tftp-server-name = \\"192.168.122.1\\";', 'option bootfile-name = \\"poap.cfg/something.py\\";'],
                 @dhcp.send(:poap_options_statements, :filename => 'poap.cfg/something.py', :nextServer => '192.168.122.1')
  end

  def test_subnet_matching_without_parameters_or_declarations
    assert "subnet 192.168.1.0 netmask 255.255.255.128 {}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_ip_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {option subnet-mask 255.255.255.192;}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_numerical_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {adaptive-lease-time-threshold 50;}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_timestamp_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {dynamic-bootp-lease-cutoff 5 2016/11/11 01:01:00;}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_string_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {filename \"filename\";}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_spaces_in_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 { option subnet-mask 255.255.255.192 ; }".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}}".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration_and_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}option subnet-mask 255.255.255.192;}".
             match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_mathing_with_spaces_in_declarations
    assert "subnet 192.168.1.0 netmask 255.255.255.128 { pool\n{ range abc ; } }".match(Proxy::DHCP::ISC::SUBNET_BLOCK_REGEX)
  end

  def test_loadSubnets_loads_managed_subnets
    subnets = @dhcp.parse_config_for_subnets
    assert_equal 4, subnets.size
  end

  def test_managed_subnets_options
    subnets = @dhcp.parse_config_for_subnets
    assert_not_nil subnets[0].options
    assert_not_nil subnets[1].options
    assert_not_nil subnets[2].options
    assert_equal Hash.new, subnets[3].options
  end

  def test_managed_subnets_network_addresses
    subnets = @dhcp.parse_config_for_subnets
    assert_equal "192.168.122.0", subnets[0].network
    assert_equal "192.168.123.0", subnets[1].network
    assert_equal "192.168.124.0", subnets[2].network
    assert_equal "192.168.1.0", subnets[3].network
  end

  def test_managed_subnets_netmask
    subnets = @dhcp.parse_config_for_subnets
    assert_equal "255.255.255.0", subnets[0].netmask
    assert_equal "255.255.255.192", subnets[1].netmask
    assert_equal "255.255.255.0", subnets[2].netmask
    assert_equal "255.255.255.128", subnets[3].netmask
  end

  def test_managed_subnets_router_addresses
    subnets = @dhcp.parse_config_for_subnets
    assert_equal ["192.168.122.250"], subnets[0].options[:routers]
    assert_equal nil, subnets[0].options[:routers][1]
    assert_equal ["192.168.123.1"], subnets[1].options[:routers]
    assert_equal ["192.168.124.1", "192.168.124.2"], subnets[2].options[:routers]
  end

  def test_managed_subnets_domain_name_servers
    subnets = @dhcp.parse_config_for_subnets
    assert_equal nil, subnets[0].options[:domain_name_servers]
    assert_equal ["192.168.123.1"], subnets[1].options[:domain_name_servers]
    assert_equal ["192.168.123.1", "192.168.122.250"], subnets[2].options[:domain_name_servers]
  end

  def test_managed_subnets_range
    subnets = @dhcp.parse_config_for_subnets
    assert_equal nil, subnets[0].options[:range]
    assert_equal ["192.168.123.2", "192.168.123.62"], subnets[1].options[:range]
    assert_equal nil, subnets[2].options[:range]
  end

  def test_parse_config_and_leases
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")

    @subnet_service.add_subnet(subnet)
    @dhcp.loadSubnetData(subnet)

    assert_equal 8, @subnet_service.all_hosts("192.168.122.0").size + @subnet_service.all_leases("192.168.122.0").size
    assert_nil @subnet_service.find_host_by_hostname("deleted.example.com")
    assert_nil @subnet_service.find_host_by_ip(subnet.network, "192.168.122.0")
    assert_not_nil @subnet_service.find_host_by_hostname("undeleted.example.com")
    assert_not_nil @subnet_service.find_host_by_ip(subnet.network, "192.168.122.35")
  end

  def test_get_ip_list_from_config_line
    assert_equal ["192.168.1.1"], @dhcp.get_ip_list_from_config_line("option foo-bar 192.168.1.1")
    assert_equal ["192.168.1.1", "192.168.20.10"], @dhcp.get_ip_list_from_config_line("option foo-bar 192.168.1.1,192.168.20.10")
    assert_equal ["192.168.1.1", "192.168.20.10", "192.168.130.100"], @dhcp.get_ip_list_from_config_line("option foo-bar 192.168.1.1, 192.168.20.10,192.168.130.100")
    assert_equal ["192.168.1.1", "192.168.20.10", "192.168.130.100", "10.1.1.1"], @dhcp.get_ip_list_from_config_line("option foo-bar 192.168.1.1, 192.168.20.10,192.168.130.100,      10.1.1.1")
  end

  def test_get_range_from_config_line
    assert_equal ["192.168.1.1", "192.168.1.254"], @dhcp.get_range_from_config_line("range 192.168.1.1 192.168.1.254")
    assert_equal ["192.168.10.1", "192.168.10.8"], @dhcp.get_range_from_config_line("range 192.168.10.1 192.168.10.8")
    assert_equal ["10.16.1.1", "10.16.1.254"], @dhcp.get_range_from_config_line("range 10.16.1.1 10.16.1.254")
  end
end
