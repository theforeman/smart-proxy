require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_native_ms/dhcp_native_ms'
require 'dhcp_native_ms/dhcp_native_ms_main'
require 'dhcp/sparc_attrs'

class DHCPServerMicrosoftTest < Test::Unit::TestCase
  # rubocop:disable Metrics/MethodLength
  def setup
    @subnet_service = Proxy::DHCP::SubnetService.initialized_instance
    @server = Proxy::DHCP::NativeMS::Provider.new("1.2.3.4", nil, @subnet_service)

    @server.stubs(:execute).with("show scope", "Enumerated the scopes on 1.2.3.4").returns('
==============================================================================
 Scope Address  - Subnet Mask    - State        - Scope Name          -  Comment
==============================================================================

 192.168.166.0   - 255.255.255.128-Active        -WLAN SMW Clients BRS -WLAN range SMW
 192.168.230.0   - 255.255.255.128-Active        -WLAN SMW Clients BRS -WLAN range SMW
 192.168.204.0   - 255.255.255.0  -Active        -Client VLAN Scope    -DC Standardiza
 192.168.205.0   - 255.255.255.128-Active        -Server VLAN Scope    -DC Standardiza
 192.168.205.128 - 255.255.255.128-Active        -Management VLAN Scope-DC Standardiza
 192.168.216.0   - 255.255.254.0  -Active        -DC BRS               -

 Total No. of Scopes = 6
Command completed successfully.'.split("\n"))
    @server.stubs(:execute).with("scope 192.168.216.0 show client 1", "Enumerated hosts on 192.168.216.0").returns('

Changed the current scope context to 192.168.216.0 scope.

Type : N - NONE, D - DHCP B - BOOTP, U - UNSPECIFIED, R - RESERVATION IP
============================================================================================
IP Address      - Subnet Mask    - Unique ID           - Lease Expires        -Type -Name
============================================================================================

192.168.216.25   - 255.255.254.0  -e4-11-5b-ad-a5-da   - NEVER EXPIRES        -U-  BRSSVM01L.brs.someware.com
192.168.217.5    - 255.255.254.0  - 64-51-06-a1-66-b5   -6/13/2016 7:29:13 AM   -D-  BRSNCNU4309QH3.eu.someware.com
192.168.217.6    - 255.255.254.0  - 10-0b-a9-02-30-e4   -6/12/2016 7:48:16 AM   -D-  BRSNCNU15112P6.eu.someware.com
192.168.217.13   - 255.255.254.0  - e4-11-5b-2d-d4-fe   -6/13/2016 9:20:27 AM   -D-  BRSNCZC2050P23.eu.someware.com
192.168.217.14   - 255.255.254.0  -00-08-02-8e-73-0e   - NEVER EXPIRES        -U-  brsw002a.eu.someware.com
192.168.217.134  - 255.255.254.0  - 64-80-99-8a-e8-9b   -6/13/2016 11:18:24 AM  -D-  BRSN5CG54755H5.eu.someware.com
192.168.217.138  - 255.255.254.0  - 3c-a8-2a-19-88-98   -6/11/2016 10:13:13 AM  -D-  brssvm03l.brs.someware.com
192.168.217.140  - 255.255.254.0  - dc-4a-3e-63-96-fa   -6/13/2016 11:15:09 AM  -D-  BRSN5CG54755HT.eu.someware.com
192.168.217.141  - 255.255.254.0  -00-0f-fe-59-db-a5   - NEVER EXPIRES        -U-  brsutest.brs.someware.com
192.168.217.142  - 255.255.254.0  - 64-80-99-8a-e8-3c   -6/13/2016 11:20:33 AM  -D-  BRSN5CG54755FT.eu.someware.com
192.168.217.144  - 255.255.254.0  - f4-ce-46-10-2a-d0   -6/12/2016 2:08:47 AM   -D-  BRSWCZC1045563.eu.someware.com
192.168.217.148  - 255.255.254.0  - 70-5a-0f-d1-0a-78   -6/13/2016 9:52:27 AM   -D-  BRSN5CG616217K.eu.someware.com

No of Clients(version 4): 12 in the Scope : 192.168.216.0.

Command completed successfully.

'.split("\n"))
    @server.stubs(:execute).with("scope 192.168.205.0 Show OptionValue", "Queried 192.168.205.0 options").returns('
Changed the current scope context to 192.168.205.0 scope.

Options for Scope 192.168.205.0:

        DHCP Standard Options :
        General Option Values:
        OptionId : 81
        Option Value:
                Number of Option Elements = 1
                Option Element Type = DWORD
                Option Element Value = 0
        OptionId : 51
        Option Value:
                Number of Option Elements = 1
                Option Element Type = DWORD
                Option Element Value = 691200
        For vendor class [SPARC-Enterprise-T5120]:
        OptionId : 3
        Option Value:
                Number of Option Elements = 1
                Option Element Type = IPADDRESS
                Option Element Value = 192.168.205.1
Command completed successfully.
    '.split("\n"))
    @server.stubs(:execute).with(
        regexp_matches(/\Ascope 192.168.216.0 Show ReservedOptionValue 192.168.216.25/),
        regexp_matches(/\AQueried .+ options/)).returns('
Changed the current scope context to 192.168.216.0 scope.

Options for the Reservation Address 192.168.216.25 in the Scope 192.168.216.0 :

        DHCP Standard Options :
        General Option Values:
        OptionId : 66
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = BRSSVM01L.brs.someware.com
        OptionId : 67
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = gi-install/pxelinux.0
        OptionId : 12
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brslcs25
Command completed successfully.
'.split("\n"))
    @server.load_subnets
  end

  def test_should_load_subnets
    subnets = @subnet_service.all_subnets.map { |s| s.network }

    assert_equal 6, subnets.size
    assert subnets.include?("192.168.166.0")
    assert subnets.include?("192.168.230.0")
    assert subnets.include?("192.168.204.0")
    assert subnets.include?("192.168.205.0")
    assert subnets.include?("192.168.205.128")
    assert subnets.include?("192.168.216.0")
  end

  def test_subnet_should_have_options
    subnet = @server.find_subnet "192.168.205.0"
    @server.load_subnet_options subnet

    assert !subnet.options.empty?
  end

  def test_subnet_should_have_options_and_values
    subnet = @server.find_subnet "192.168.205.0"
    @server.load_subnet_options subnet

    assert !subnet.options.any? { |o,v| o.to_s.empty? || v.nil? || v.to_s.empty? }
  end

  def test_records_should_have_options
    @server.load_subnet_data(@server.find_subnet("192.168.216.0"))
    record = @subnet_service.all_hosts("192.168.216.0").first
    @server.loadRecordOptions record

    assert !record.options.empty?
  end

  def test_records_are_correct_type
    @server.load_subnet_data(@server.find_subnet('192.168.216.0'))
    assert @subnet_service.find_lease_by_mac('192.168.216.0','64:51:06:a1:66:b5').ip == '192.168.217.5'
    assert @subnet_service.find_host_by_mac('192.168.216.0', 'e4:11:5b:ad:a5:da').ip == '192.168.216.25'
  end

  def test_records_should_have_options_and_values
    @server.load_subnet_data(@server.find_subnet("192.168.216.0"))
    record = @subnet_service.all_hosts("192.168.216.0").first
    @server.loadRecordOptions record

    assert !record.options.any? { |o,v| o.to_s.empty? || v.nil? || v.to_s.empty? }
  end

  def test_parse_standard_options
    to_parse = '
        DHCP Standard Options :
        General Option Values:
        OptionId : 66
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brsla025.brs.someware.com
        OptionId : 67
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = gi-install/pxelinux.0
        OptionId : 13
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brslcs25
Command completed successfully.
'.split("\n")
    parsed = @server.parse_options(to_parse)
    assert_equal 2, parsed.size
    assert_equal "brsla025.brs.someware.com", parsed[:nextServer]
    assert_equal "gi-install/pxelinux.0", parsed[:filename]
  end

  def test_parse_vendor_options
    to_parse = '
        For vendor class [SPARC-Enterprise-T5120]:
        OptionId : 66
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brsla025.brs.someware.com
        OptionId : 67
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = gi-install/pxelinux.0
        OptionId : 2
        Option Value:
                Number of Option Elements = 1
                Option Element Type = IPADDRESS
                Option Element Value = 192.168.205.1
        OptionId : 3
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brsla025.brs.someware.com
Command completed successfully.
'.split("\n")
    parsed = @server.parse_options(to_parse)
    assert_equal 3, parsed.size
    assert_equal "<SPARC-Enterprise-T5120>", parsed[:vendor]
    assert_equal "192.168.205.1", parsed[:root_server_ip]
    assert_equal "brsla025.brs.someware.com", parsed[:root_server_hostname]
  end

  def test_parse_standard_and_vendor_options
    to_parse = '
        DHCP Standard Options :
        General Option Values:
        OptionId : 68
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brsla025.brs.someware.com
        OptionId : 12
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brslcs25
        For vendor class [SPARC-Enterprise-T5120]:
        OptionId : 12
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = /vol/solgi_5.10/sol10_hw0910
Command completed successfully.
'.split("\n")
    parsed = @server.parse_options(to_parse)
    assert_equal 3, parsed.size
    assert_equal "<SPARC-Enterprise-T5120>", parsed[:vendor]
    assert_equal "brslcs25", parsed[:hostname]
    assert_equal "/vol/solgi_5.10/sol10_hw0910", parsed[:install_path]
  end

  def test_should_add_record
    to_add = { "hostname" => "test.example.com", "ip" => "192.168.166.11",
               "mac" => "00:11:bb:cc:dd:ee", "network" => "192.168.166.0/255.255.255.0",
               "PXEClient" => "pxeclientval" }

    @server.expects(:execute).with('scope 192.168.166.0 add reservedip 192.168.166.11 0011bbccddee test.example.com', 'Added DHCP reservation for test.example.com (192.168.166.11 / 00:11:bb:cc:dd:ee)')
    @server.expects(:execute).with('scope 192.168.166.0 set reservedoptionvalue 192.168.166.11 12 String "test.example.com"', nil, true)
    @server.expects(:execute).with('scope 192.168.166.0 set reservedoptionvalue 192.168.166.11 60 String "pxeclientval"', nil, true)
    @server.add_record(to_add)
  end

  def test_should_raise_on_option_error
    to_add = { "hostname" => "test.example.com", "ip" => "192.168.166.11",
               "mac" => "00:11:bb:cc:dd:ee", "network" => "192.168.166.0/255.255.255.0",
             }

    @server.expects(:execute).with('scope 192.168.166.0 add reservedip 192.168.166.11 0011bbccddee test.example.com', 'Added DHCP reservation for test.example.com (192.168.166.11 / 00:11:bb:cc:dd:ee)')
    @server.expects(:execute).with('scope 192.168.166.0 set reservedoptionvalue 192.168.166.11 12 String "test.example.com"', nil, true).raises(Proxy::DHCP::Error)
    @server.stubs(:execute).with('scope 192.168.166.0 set reservedoptionvalue 192.168.166.11 60 String ""', nil, true) # may or may not be called
    assert_raises(::Proxy::DHCP::Error) { @server.add_record(to_add) }
  end

end
