require 'test_helper'
require 'dhcp/sparc_attrs'
require 'json'
require 'dhcp/dhcp'
require 'dhcp_isc/dhcp_isc'
require 'dhcp_isc/dhcp_isc_main'
require 'dhcp_common/dependency_injection/dependencies'

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
    ::Proxy::DhcpPlugin.load_test_settings({})
    ::Proxy::DHCP::ISC::Plugin.load_test_settings({})

    @subnet_service =  Proxy::DHCP::SubnetService.new
    @dhcp = Proxy::DHCP::ISC::Provider.new.initialize_for_testing(
        :name => '192.168.122.1', :config_file => './test/fixtures/dhcp/dhcp.conf',
        :leases_file => './test/fixtures/dhcp/dhcp.leases', :service => @subnet_service, :omapi_port => 999)
  end

  class DhcpIscProviderForTesting < ::Proxy::DHCP::ISC::Provider
    attr_reader :config_file, :leases_file, :key_name, :key_secret, :omapi_port
  end

  def test_isc_provider_initialization
    ::Proxy::DhcpPlugin.load_test_settings(:server => 'a_server')
    ::Proxy::DHCP::ISC::Plugin.load_test_settings(:config => 'config_file', :leases => 'leases_file',
                                                  :omapi_port => '7777', :key_name => 'key_name',
                                                  :key_secret => 'key_secret')

    provider = DhcpIscProviderForTesting.new
    assert_equal 'a_server', provider.name
    assert_equal 'config_file', provider.config_file
    assert_equal 'leases_file', provider.leases_file
    assert_equal '7777', provider.omapi_port
    assert_equal 'key_name', provider.key_name
    assert_equal 'key_secret', provider.key_secret
  end

  def test_omcmd_server_connect
    @dhcp.stubs(:which).returns('fakeshell')
    omio = OMIO.new
    IO.expects(:popen).with("/bin/sh -c 'fakeshell 2>&1'", "r+").returns(omio)
    @dhcp.omcmd('connect')
    assert_equal "server 192.168.122.1", omio.input_commands[0]
    assert_equal "port 999", omio.input_commands[1]
    assert_equal "connect", omio.input_commands[2]
    assert_equal "new host", omio.input_commands[3]
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
    assert "subnet 192.168.1.0 netmask 255.255.255.128 {}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_ip_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {option subnet-mask 255.255.255.192;}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_numerical_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {adaptive-lease-time-threshold 50;}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_timestamp_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {dynamic-bootp-lease-cutoff 5 2016/11/11 01:01:00;}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_string_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {filename \"filename\";}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_spaces_in_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 { option subnet-mask 255.255.255.192 ; }".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}}".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_subnet_matching_with_declaration_and_parameter
    assert "subnet 192.168.123.0 netmask 255.255.255.192 {pool{range 192.168.42.200 192.168.42.254;}option subnet-mask 255.255.255.192;}".
      match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_mathing_with_spaces_in_declarations
    assert "subnet 192.168.1.0 netmask 255.255.255.128 { pool\n{ range abc ; } }".match(Proxy::DHCP::ISC::Provider::SUBNET_BLOCK_REGEX)
  end

  def test_parse_config_for_subnets
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

  def test_parse_config_loads_managed_subnets_only
    @dhcp = Proxy::DHCP::ISC::Provider.new.initialize_for_testing(
        :name => '192.168.122.1', :config_file => './test/fixtures/dhcp/dhcp.conf',
        :leases_file => './test/fixtures/dhcp/dhcp.leases',
        :service => @subnet_service, :omapi_port => 999, :subnets => ["192.168.122.0/255.255.255.0", "192.168.1.0/255.255.255.128"])

    subnets = @dhcp.parse_config_for_subnets

    assert_equal 2, subnets.size
    assert_equal "192.168.122.0/255.255.255.0", subnets.first.to_s
    assert_equal "192.168.1.0/255.255.255.128", subnets.last.to_s
  end

  def test_parse_config_and_leases
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")

    @subnet_service.add_subnet(subnet)
    @dhcp.load_subnet_data(subnet)

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
