require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_native_ms/dhcp_native_ms'
require 'dhcp_native_ms/dhcp_native_ms_main'
require 'dhcp/sparc_attrs'
require 'dhcp_common/dependency_injection/dependencies'

class DHCPServerMicrosoftTest < Test::Unit::TestCase

  # rubocop:disable Metrics/MethodLength
  def setup
    ::Proxy::DhcpPlugin.load_test_settings({})
    @subnet_service = Proxy::DHCP::SubnetService.new
    @server = Proxy::DHCP::NativeMS::Provider.new.initialize_for_testing(:name => "1.2.3.4",
                                                                         :service => @subnet_service)
    @server.stubs(:execute).with("show scope", "Enumerated the scopes on 1.2.3.4").returns('
==============================================================================
 Scope Address  - Subnet Mask    - State        - Scope Name          -  Comment
==============================================================================

 172.24.166.0   - 255.255.255.128-Active        -WLAN SMW Clients BRS -WLAN range SMW
 172.24.230.0   - 255.255.255.128-Active        -WLAN SMW Clients BRS -WLAN range SMW
 172.29.204.0   - 255.255.255.0  -Active        -Client VLAN Scope    -DC Standardiza
 172.29.205.0   - 255.255.255.128-Active        -Server VLAN Scope    -DC Standardiza
 172.29.205.128 - 255.255.255.128-Active        -Management VLAN Scope-DC Standardiza
 172.29.216.0   - 255.255.254.0  -Active        -DC BRS               -

 Total No. of Scopes = 6
Command completed successfully.'.split("\n"))
    @server.stubs(:execute).with("scope 172.29.205.0 show reservedip", "Enumerated hosts on 172.29.205.0").returns('
Changed the current scope context to 172.29.205.0 scope.

===============================================================
  Reservation Address -    Unique ID
===============================================================

    172.29.205.56     -    00-14-4f-40-e9-88-
    172.29.205.30     -    00-0c-29-03-f4-24-
    172.29.205.62     -    00-14-4f-41-09-e8-
    172.29.205.83     -    00-1b-24-93-34-89-
    172.29.205.34     -    00-1e-68-04-a4-8b-
    172.29.205.29     -    00-0c-29-7b-05-ce-
    172.29.205.32     -    00-0c-29-64-85-f0-
    172.29.205.37     -    00-1e-68-04-a0-df-
    172.29.205.35     -    00-1e-68-04-a0-eb-
    172.29.205.36     -    00-1e-68-04-a7-0f-
    172.29.205.38     -    00-1e-68-04-a0-db-
    172.29.205.39     -    00-1e-68-04-a4-17-
    172.29.205.44     -    00-14-4f-41-09-90-
    172.29.205.45     -    00-14-4f-40-ea-98-
    172.29.205.52     -    00-14-4f-41-0b-74-
    172.29.205.53     -    00-14-4f-40-67-24-
    172.29.205.54     -    00-14-4f-40-db-80-
    172.29.205.55     -    00-14-4f-40-e1-f0-
    172.29.205.58     -    00-14-4f-40-e2-54-
    172.29.205.79     -    00-1b-24-1d-e6-60-
    172.29.205.78     -    00-1b-24-1d-e6-c8-
    172.29.205.77     -    00-1b-24-1d-e8-e0-
    172.29.205.80     -    00-1b-24-5b-e0-62-
    172.29.205.81     -    00-1b-24-93-34-39-
    172.29.205.82     -    00-04-23-dd-29-98-
    172.29.205.63     -    00-14-4f-41-09-cc-
    172.29.205.5      -    01-01-01-00-00-05-
    172.29.205.40     -    00-14-4f-41-0b-70-
    172.29.205.43     -    00-14-4f-41-09-c0-
    172.29.205.28     -    01-01-01-00-02-08-
    172.29.205.85     -    00-21-28-57-42-ce-
    172.29.205.86     -    00-21-28-57-41-c2-
    172.29.205.87     -    00-21-28-57-44-2a-
    172.29.205.88     -    00-14-4f-ca-ae-c8-
    172.29.205.89     -    00-21-28-57-40-e2-
    172.29.205.90     -    00-14-4f-ca-6a-70-
    172.29.205.70     -    00-21-28-57-41-72-
    172.29.205.31     -    99-10-10-11-12-12-
    172.29.205.10     -    00-1b-24-1d-e9-e4-
    172.29.205.57     -    00-14-4f-41-0a-18-
    172.29.205.76     -    00-e0-81-bb-05-18-
    172.29.205.71     -    00-14-4f-ca-91-48-
    172.29.205.91     -    00-e0-81-d2-ea-12-
    172.29.205.92     -    00-e0-81-d2-ea-06-
    172.29.205.93     -    00-e0-81-d2-01-aa-
    172.29.205.94     -    00-e0-81-d1-fe-2a-
    172.29.205.95     -    00-e0-81-d2-e9-aa-
    172.29.205.20     -    00-0c-29-e4-cd-0c-
    172.29.205.21     -    00-0c-29-3b-ec-dc-
    172.29.205.22     -    00-0c-29-cf-00-45-
    172.29.205.24     -    00-0c-29-e9-83-09-
    172.29.205.96     -    00-e0-81-d2-e9-56-
    172.29.205.6      -    00-14-4f-82-9c-ea-
    172.29.205.27     -    00-03-ba-45-79-31-
    172.29.205.23     -    00-0c-29-f6-f9-ce-
    172.29.205.25     -    00-0c-29-64-a1-f1-
    172.29.205.26     -    00-0c-29-46-8f-10-


No of ReservedIPs : 57 in the Scope : 172.29.205.0.

Command completed successfully.
'.split("\n"))
    @server.stubs(:execute).with("scope 172.29.205.0 Show OptionValue", "Queried 172.29.205.0 options").returns('
Changed the current scope context to 172.29.205.0 scope.

Options for Scope 172.29.205.0:

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
                Option Element Value = 172.29.205.1
Command completed successfully.
    '.split("\n"))
    @server.stubs(:execute).with(
        regexp_matches(/^scope 172.29.205.0 Show ReservedOptionValue 172.29.205.25/),
        regexp_matches(/^Queried .+ options/)).returns('
Changed the current scope context to 172.29.205.0 scope.

Options for the Reservation Address 172.29.205.25 in the Scope 172.29.205.0 :

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
        OptionId : 12
        Option Value:
                Number of Option Elements = 1
                Option Element Type = STRING
                Option Element Value = brslcs25
Command completed successfully.
'.split("\n"))
    @server.load_subnets
  end

  def test_ms_provider_initialization
    ::Proxy::DhcpPlugin.load_test_settings(:server => 'a_server')
    assert_equal 'a_server', Proxy::DHCP::NativeMS::Provider.new.name
  end

  def test_should_load_subnets
    subnets = @subnet_service.all_subnets.map { |s| s.network }

    assert_equal 6, subnets.size
    assert subnets.include?("172.24.166.0")
    assert subnets.include?("172.24.230.0")
    assert subnets.include?("172.29.204.0")
    assert subnets.include?("172.29.205.0")
    assert subnets.include?("172.29.205.128")
    assert subnets.include?("172.29.216.0")
  end

  def test_subnet_should_have_options
    subnet = @server.find_subnet "172.29.205.0"
    @server.load_subnet_options subnet

    assert !subnet.options.empty?
  end

  def test_subnet_should_have_options_and_values
    subnet = @server.find_subnet "172.29.205.0"
    @server.load_subnet_options subnet

    assert !subnet.options.any? { |o,v| o.to_s.empty? || v.nil? || v.to_s.empty? }
  end

  def test_records_should_have_options
    @server.load_subnet_data(@server.find_subnet("172.29.205.0"))
    record = @subnet_service.all_hosts("172.29.205.0").first
    @server.loadRecordOptions record

    assert !record.options.empty?
  end

  def test_records_should_have_options_and_values
    @server.load_subnet_data(@server.find_subnet("172.29.205.0"))
    record = @subnet_service.all_hosts("172.29.205.0").first
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
                Option Element Value = 172.29.205.1
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
    assert_equal "172.29.205.1", parsed[:root_server_ip]
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
    to_add = { "hostname" => "test.example.com", "ip" => "172.24.166.11",
               "mac" => "00:11:bb:cc:dd:ee", "network" => "172.24.166.0/255.255.255.0",
               "PXEClient" => "pxeclientval" }

    @server.expects(:execute).with('scope 172.24.166.0 add reservedip 172.24.166.11 0011bbccddee test.example.com', 'Added DHCP reservation for test.example.com (172.24.166.11 / 00:11:bb:cc:dd:ee)')
    @server.expects(:execute).with('scope 172.24.166.0 set reservedoptionvalue 172.24.166.11 12 String "test.example.com"', nil, true)
    @server.expects(:execute).with('scope 172.24.166.0 set reservedoptionvalue 172.24.166.11 60 String "pxeclientval"', nil, true)
    @server.add_record(to_add)
  end

  def test_should_raise_on_option_error
    to_add = { "hostname" => "test.example.com", "ip" => "172.24.166.11",
               "mac" => "00:11:bb:cc:dd:ee", "network" => "172.24.166.0/255.255.255.0",
             }

    @server.expects(:execute).with('scope 172.24.166.0 add reservedip 172.24.166.11 0011bbccddee test.example.com', 'Added DHCP reservation for test.example.com (172.24.166.11 / 00:11:bb:cc:dd:ee)')
    @server.expects(:execute).with('scope 172.24.166.0 set reservedoptionvalue 172.24.166.11 12 String "test.example.com"', nil, true).raises(Proxy::DHCP::Error)
    @server.expects(:execute).with('scope 172.24.166.0 set reservedoptionvalue 172.24.166.11 60 String ""', nil, true)
    assert_raises ::Proxy::DHCP::Error do
      @server.add_record(to_add)
    end
  end

end
