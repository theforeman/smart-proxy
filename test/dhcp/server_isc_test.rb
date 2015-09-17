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

    assert_equal ['option tftp-server-name = 192.168.122.1;', 'option bootfile-name = \\"poap.cfg/something.py\\";'],
                 @dhcp.send(:poap_options_statements, :filename => 'poap.cfg/something.py', :nextServer => '192.168.122.1')
  end

  def test_loadSubnets_loads_managed_subnets
    subnets = @dhcp.loadSubnets

    assert_equal 1, subnets.size
    assert_equal "192.168.122.0", subnets.first.network
  end

  def test_parse_config_and_leases
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")

    @subnet_service.add_subnet(subnet)
    @dhcp.loadSubnetData(subnet)

    assert_equal 7, @subnet_service.all_hosts("192.168.122.0").size + @subnet_service.all_leases("192.168.122.0").size
  end
end
