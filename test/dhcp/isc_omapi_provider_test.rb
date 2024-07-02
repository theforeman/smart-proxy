require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp/dhcp_plugin'
require 'dhcp/sparc_attrs'
require 'dhcp_common/isc/omapi_provider'

class IscOmapiProviderTest < Test::Unit::TestCase
  class OMIO
    attr_reader :input_commands

    def initialize
      @input_commands = []
    end

    def puts(str)
      @input_commands << str
    end
  end

  include SparcAttrs

  def setup
    @dhcp = Proxy::DHCP::CommonISC::IscOmapiProvider.new('192.168.122.1', '999', nil, 'key_name', 'key_secret', nil)
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
    ['01:02:03:04:05:06', '80:00:02:08:fe:80:00:00:00:00:00:00:00:02:aa:bb:cc:dd:ee:ff'].each do |mac_address|
      omio = OMIO.new
      @dhcp.stubs(:om).returns(omio)
      @dhcp.expects(:om_connect)
      @dhcp.expects(:om_disconnect)

      @dhcp.expects(:solaris_options_statements).returns([])
      @dhcp.expects(:ztp_options_statements).returns([])
      @dhcp.expects(:poap_options_statements).returns([])

      record_to_add = Proxy::DHCP::Reservation.new('a-test-01',
                                                   '192.168.42.100',
                                                   mac_address,
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
        "create",
      ]
      assert_equal expected_om_output, omio.input_commands
    end
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

    @dhcp.del_record(record_to_delete)

    expected_om_output = [
      "set hardware-address = #{record_to_delete.mac}",
      "open",
      "remove",
    ]

    assert_equal expected_om_output, omio.input_commands
  end

  def test_sparc_host_quirks
    assert_equal [], @dhcp.solaris_options_statements({})

    assert_equal [
      %q{option SUNW.JumpStart-server \"192.168.122.24:/Solaris/jumpstart\";},
      %q{option SUNW.install-path \"/Solaris/install/Solaris_5.10_sparc_hw0811\";},
      %q{option SUNW.install-server-hostname \"example-server.example.com\";},
      %q{option SUNW.install-server-ip-address 192.168.122.24;},
      %q{option SUNW.root-path-name \"/Solaris/install/Solaris_5.10_sparc_hw0811/Solaris_10/Tools/Boot\";},
      %q{option SUNW.root-server-hostname \"example-server.example.com\";},
      %q{option SUNW.root-server-ip-address 192.168.122.24;},
      %q{option SUNW.sysid-config-file-server \"192.168.122.24:/Solaris/jumpstart/sysidcfg/sysidcfg_primary\";},
      %q{vendor-option-space SUNW;},
    ], @dhcp.solaris_options_statements(sparc_attrs).sort
  end

  def test_ztp_quirks
    assert_equal [], @dhcp.ztp_options_statements({})
    assert_equal [], @dhcp.ztp_options_statements(:filename => 'foo.cfg')
    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";'],
                 @dhcp.ztp_options_statements(:filename => 'ztp.cfg', :nextServer => '192.168.122.1')
    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";'],
                 @dhcp.ztp_options_statements(:filename => 'ztp.cfg', :nextServer => '192.168.122.1', :ztp_vendor => 'junos')
    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";',
                  'option option-143 = \\"vrpfile=firmware.cc;webfile=web.7z;\\";'],
                 @dhcp.ztp_options_statements(:filename => 'ztp.cfg', :nextServer => '192.168.122.1',
                                              :ztp_vendor => 'huawei', :ztp_firmware => { :core => 'firmware.cc',
                                                                                          :web => 'web.7z'})
  end

  def test_poap_quirks
    assert_equal [], @dhcp.poap_options_statements({})
    assert_equal [], @dhcp.poap_options_statements(:filename => 'foo.cfg')

    assert_equal ['option tftp-server-name = \\"192.168.122.1\\";', 'option bootfile-name = \\"poap.cfg/something.py\\";'],
                 @dhcp.poap_options_statements(:filename => 'poap.cfg/something.py', :nextServer => '192.168.122.1')
  end

  def test_boot_server_ip
    assert_equal "7f:00:00:01", @dhcp.bootServer("127.0.0.1")
  end

  def test_boot_server_hostname
    ::Proxy::LoggingResolv.any_instance.expects(:getresource).with("ptr-doesnotexist.example.com", Resolv::DNS::Resource::IN::A).returns(Resolv::DNS::Resource::IN::A.new("127.0.0.2"))
    assert_equal "7f:00:00:02", @dhcp.bootServer("ptr-doesnotexist.example.com")
  end

  def test_validate_ip
    assert_nothing_raised do
      @dhcp.validate_supported_address("192.168.122.0", "192.168.122.0", "192.168.122.0", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_not_validate_ipv6
    assert_raises Proxy::Validations::InvalidIPAddress do
      @dhcp.validate_supported_address("192.168.122.0", "192.168.122.0", "2001:db8::8:800:200c:417a", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_raise_exception_for_invalid_ip
    assert_raises Proxy::Validations::InvalidIPAddress do
      @dhcp.validate_supported_address("192.168.122.0", "192.168.122.0", "266.168.122.0", "192.168.122.0", "192.168.122.0")
    end
  end

  def test_should_raise_exception_for_invalid_ip_single
    assert_raises Proxy::Validations::InvalidIPAddress do
      @dhcp.validate_supported_address("266.168.122.0")
    end
  end
end
