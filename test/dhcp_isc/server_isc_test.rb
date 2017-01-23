require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp/dhcp_plugin'
require 'dhcp/sparc_attrs'
require 'dhcp_common/server'
require 'dhcp_isc/dhcp_isc_main'

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
    @dhcp = Proxy::DHCP::ISC::Provider.new('192.168.122.1', '999', nil, 'key_name', 'key_secret', nil)
  end

  def test_om
    @dhcp.expects(:which).returns('fakeshell')
    IO.expects(:popen).with("/bin/sh -c 'fakeshell 2>&1'", "r+")
    @dhcp.om
  end

  def test_omcmd_connect
    omio = OMIO.new
    @dhcp.stubs(:om).returns(omio)

    @dhcp.om_connect

    assert_equal 'key key_name "key_secret"', omio.input_commands[0]
    assert_equal "server 192.168.122.1", omio.input_commands[1]
    assert_equal "port 999", omio.input_commands[2]
    assert_equal "connect", omio.input_commands[3]
    assert_equal "new host", omio.input_commands[4]
  end

  def test_om_add_record
    omio = OMIO.new
    @dhcp.stubs(:om).returns(omio)
    @dhcp.expects(:om_connect)
    @dhcp.expects(:om_disconnect)

    @dhcp.expects(:solaris_options_statements).returns([])
    @dhcp.expects(:ztp_options_statements).returns([])
    @dhcp.expects(:poap_options_statements).returns([])

    record_to_add = Proxy::DHCP::Reservation.new('a-test-01',
                                                 '192.168.42.100',
                                                 '01:02:03:04:05:06',
                                                 Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0'),
                                                 :hostname => 'a-test',
                                                 :filename => 'a_file',
                                                 :nextServer => '192.168.42.10')

    @dhcp.om_add_record(record_to_add)

    expected_om_output = [
      "set name = \"#{record_to_add.name}\"",
      "set ip-address = #{record_to_add.ip}",
      "set hardware-address = #{record_to_add.mac}",
      "set hardware-type = 1",
      "set statements = \"filename = \\\"#{record_to_add.options[:filename]}\\\"; next-server = c0:a8:2a:0a; option host-name = \\\"#{record_to_add.hostname}\\\";\"",
      "create"
    ]
    assert_equal expected_om_output, omio.input_commands
  end

  def test_del_record
    omio = OMIO.new
    @dhcp.stubs(:om).returns(omio)
    @dhcp.expects(:om_connect)
    @dhcp.expects(:om_disconnect)

    subnet = Proxy::DHCP::Subnet.new('192.168.42.0', '255.255.255.0')
    record_to_delete = Proxy::DHCP::Reservation.new('a-test',
                                                    '192.168.42.100',
                                                    '01:02:03:04:05:06',
                                                    subnet,
                                                    :deleteable => true)

    @dhcp.del_record(subnet, record_to_delete)

    expected_om_output = [
      "set hardware-address = #{record_to_delete.mac}",
      "open",
      "remove"
    ]

    assert_equal expected_om_output, omio.input_commands
  end

  def test_sparc_host_quirks
    assert_equal [], @dhcp.solaris_options_statements({})

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
    ], @dhcp.solaris_options_statements(sparc_attrs).sort
  end

  def test_ztp_quirks
    assert_equal [], @dhcp.ztp_options_statements({})
    assert_equal [], @dhcp.ztp_options_statements(:filename => 'foo.cfg')
    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";'],
                 @dhcp.ztp_options_statements(:filename => 'ztp.cfg', :nextServer => '192.168.122.1')
  end

  def test_poap_quirks
    assert_equal [], @dhcp.poap_options_statements({})
    assert_equal [], @dhcp.poap_options_statements(:filename => 'foo.cfg')

    assert_equal ['option tftp-server-name = \\"192.168.122.1\\";', 'option bootfile-name = \\"poap.cfg/something.py\\";'],
                 @dhcp.poap_options_statements(:filename => 'poap.cfg/something.py', :nextServer => '192.168.122.1')
  end
end
