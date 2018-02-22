require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/isc/configuration_parser'

class Proxy::DHCP::CommonISC::ConfigurationParserTest < Test::Unit::TestCase
  def teardown
    Rsec::Fail.reset
  end

  def test_mac_address_parser
    assert_equal "1:1:1:1:1:1", Proxy::DHCP::CommonISC::ConfigurationParser::MAC_ADDRESS.parse!('1:1:1:1:1:1')
    assert_equal "01:01:01:01:01:01",  Proxy::DHCP::CommonISC::ConfigurationParser::MAC_ADDRESS.parse!('01:01:01:01:01:01')
    assert_equal "f1:a1:b1:c1:d1:e1", Proxy::DHCP::CommonISC::ConfigurationParser::MAC_ADDRESS.parse!('f1:a1:b1:c1:d1:e1')
  end

  def test_fixed_address_parser
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:fixed_address, '192.168.111.111'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.fixed_address.parse!('fixed-address 192.168.111.111;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:fixed_address, 'a.b.c'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.fixed_address.parse!('fixed-address a.b.c;')
  end

  def test_hardware_parser
    assert_equal  Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['ethernet', '01:01:01:01:01:01'],
                  Proxy::DHCP::CommonISC::ConfigurationParser.new.hardware.parse!('hardware ethernet 01:01:01:01:01:01;')
    assert_equal  Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['token-ring', '1:1:1:1:1:1'],
                  Proxy::DHCP::CommonISC::ConfigurationParser.new.hardware.parse!('hardware token-ring 1:1:1:1:1:1;')
  end

  MULTILINE_FQDN_LIST =<<EOFFQDNLIST
ns1.isc.org,
  ns1.isc.org,
   ns1.isc.org
EOFFQDNLIST
  def test_fqdn_list_with_various_spacing
    assert_equal ['ns1.isc.org', 'ns2.isc.org'], Proxy::DHCP::CommonISC::ConfigurationParser::FQDN_LIST.parse!('ns1.isc.org, ns2.isc.org')
    assert_equal ['ns1.isc.org', 'ns2.isc.org'], Proxy::DHCP::CommonISC::ConfigurationParser::FQDN_LIST.parse!('ns1.isc.org,   ns2.isc.org')
    assert_equal ['ns1.isc.org', 'ns2.isc.org'], Proxy::DHCP::CommonISC::ConfigurationParser::FQDN_LIST.parse!('ns1.isc.org,ns2.isc.org')
    assert_equal ['ns1.isc.org', 'ns1.isc.org', 'ns1.isc.org'], Proxy::DHCP::CommonISC::ConfigurationParser::FQDN_LIST.parse!(MULTILINE_FQDN_LIST)
  end

MULTILINE_IP_LIST =<<EOFIPLIST
204.254.239.1,
 204.254.239.2,
  204.254.239.3
EOFIPLIST
  def test_ipv4_address_list_with_various_spacing
    assert_equal ['204.254.239.1', '204.254.239.2'], Proxy::DHCP::CommonISC::ConfigurationParser::IPV4_ADDRESS_LIST.parse!('204.254.239.1, 204.254.239.2')
    assert_equal ['204.254.239.1', '204.254.239.2'], Proxy::DHCP::CommonISC::ConfigurationParser::IPV4_ADDRESS_LIST.parse!('204.254.239.1,  204.254.239.2')
    assert_equal ['204.254.239.1', '204.254.239.2'], Proxy::DHCP::CommonISC::ConfigurationParser::IPV4_ADDRESS_LIST.parse!('204.254.239.1,204.254.239.2')
    assert_equal ['204.254.239.1', '204.254.239.2', '204.254.239.3'], Proxy::DHCP::CommonISC::ConfigurationParser::IPV4_ADDRESS_LIST.parse!(MULTILINE_IP_LIST)
  end

  def test_options_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"isc.org"']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option domain-name "isc.org";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[true, 'server.domain-name', [['"isc.org"']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('supersede server.domain-name = "isc.org";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name-servers', [['ns1.isc.org'], ['ns2.isc.org']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option domain-name-servers ns1.isc.org, ns2.isc.org;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name-servers', [['204.254.239.1'], ['204.254.239.2']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option domain-name-servers 204.254.239.1, 204.254.239.2;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'routers', [['204.254.239.1'], ['204.254.239.2']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option routers  204.254.239.1, 204.254.239.2;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'my-option-int', [['1234']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option my-option-int 1234;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'my-option-bool', [['off']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option my-option-bool off;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'my-option-string', [['01:02:03'], ['04:05:06']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option my-option-string 01:02:03, 04:05:06;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'my-option-text', [['"aaaa"'], ['"bbbb"']]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option my-option-text "aaaa", "bbbb";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'my-option-record', [["10.0.0.0", "255.255.255.0", "net-0-rtr.example.com", "1"],
                                                                                                      ["10.0.1.0", "255.255.255.0", "net-1-rtr.example.com", "1"]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('option my-option-record 10.0.0.0 255.255.255.0 net-0-rtr.example.com 1, 10.0.1.0 255.255.255.0 net-1-rtr.example.com 1;')
  end

  def test_range_parser
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['1.1.1.1', '1.1.1.100', false],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.range.parse!('range 1.1.1.1 1.1.1.100;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['1.1.1.1', nil, false],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.range.parse!('range 1.1.1.1;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['1.1.1.1', nil, true],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.range.parse!('range dynamic-bootp 1.1.1.1;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['1.1.1.1', '1.1.1.100', true],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.range.parse!('range dynamic-bootp 1.1.1.1 1.1.1.100;')
  end

  def test_comment
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['#a b c']], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('#a b c')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['#a b c']], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('#a b c')
  end

  def test_subnet_matching_without_parameters_or_declarations
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128', []]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 {}")
  end

  def test_subnet_matching_with_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128',
                                                                              [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'subnet-mask', [['255.255.255.192']]]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 {option subnet-mask 255.255.255.192;}")
  end

  def test_subnet_matching_with_spaces_in_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128',
                                                                              [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'subnet-mask', [['255.255.255.192']]]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 { option subnet-mask 255.255.255.192 ; }")
  end

  def test_subnet_matching_with_unrecognized_attribute
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128',
                                                                              [Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['adaptive-lease-time-threshold', '50']]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 {adaptive-lease-time-threshold 50;}")
  end

  MULTILINE_SUBNET_WITH_OPtIONS =<<EOFSUBNETWITHOPTIONS
  subnet 192.168.1.0 netmask 255.255.255.128 {
    # a comment
    option subnet-mask 255.255.255.192;
    option domain-name "isc.org";
    range dynamic-bootp 192.168.1.1 192.168.1.100;
    group nested-group {}
    pool {}
    host nested-host { }
    something_ignored;
    unknown {}
  }
EOFSUBNETWITHOPTIONS
  def test_subnet_with_multiple_options
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128', [
      Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['# a comment'],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'subnet-mask', [['255.255.255.192']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"isc.org"']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['192.168.1.1', '192.168.1.100', true],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['nested-group', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['pool', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['nested-host', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['something_ignored']],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredBlock[['u', 'n', 'k', 'n', 'o', 'w', 'n'], []],
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_SUBNET_WITH_OPtIONS)
  end

  def test_group_without_name
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode[nil, []]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group {}")
  end

  def test_group_with_name
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['testing', []]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group testing {}")
  end

  def test_group_with_literal_as_name
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['"testing"', []]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group \"testing\" {}")
  end

  def test_group_with_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['testing', [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'subnet-mask', [['255.255.255.192']]]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group testing {option subnet-mask 255.255.255.192;}")
  end

  def test_group_with_spaces_in_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['testing', [Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'subnet-mask', [['255.255.255.192']]]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group testing { option subnet-mask 255.255.255.192 ; }")
  end

  def test_group_with_unrecognized_attribute
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['testing',
                                                                         [Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['adaptive-lease-time-threshold', '50']]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("group testing {adaptive-lease-time-threshold 50;}")
  end

  MULTILINE_GROUP =<<EOFMULTILINEGROUP
group ilom {
  default-lease-time 3600;
  option domain-name "isc.org";
  option routers 204.254.239.1, 204.254.239.2, 204.254.239.3;
  host nested-host { hardware ethernet 11:22:33:a9:61:09; fixed-address 192.168.1.200; }
  subnet 192.168.2.0 netmask 255.255.255.0 {
    option domain-name "nested.subnet.test";
  }
  group nested-group {
    option domain-name "nested.group.test";
  }
  shared-network nested-shared-network {
    option domain-name "nested.shared.network.test";
  }
}
EOFMULTILINEGROUP
  def test_group_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['ilom', [
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['default-lease-time', '3600']],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"isc.org"']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'routers', [['204.254.239.1'], ['204.254.239.2'], ['204.254.239.3']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['nested-host', [
        Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['ethernet', '11:22:33:a9:61:09'],
        Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:fixed_address, '192.168.1.200'],
      ]],
      Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.2.0', '255.255.255.0', [
        Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"nested.subnet.test"']]],
      ]],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['nested-group', [
        Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"nested.group.test"']]],
      ]],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['nested-shared-network', [
        Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"nested.shared.network.test"']]],
      ]],
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_GROUP)
  end

  def test_shared_network_with_fqdn_name
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['a.b.c', []]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("shared-network a.b.c {}")
  end

  def test_shared_network_with_literal_name
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['"testing"', []]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('shared-network "testing" {}')
  end

  MULTILINE_SHARED_NETWORK =<<EOMULTILNE_SHARED_NETWORK
  shared-network testing {
    option domain-name "test";
    option routers 204.254.239.1, 204.254.239.2;
    group nested-group {}
    subnet 192.168.2.0 netmask 255.255.255.0 {}
    pool {}
    # a comment
    deleted;
    something_ignored;
    unknown {}
    host nested-host {}
  }
EOMULTILNE_SHARED_NETWORK
  def test_multiline_shared_network
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"test"']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'routers', [['204.254.239.1'], ['204.254.239.2']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['nested-group', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.2.0', '255.255.255.0', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['pool', []],
      Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['# a comment'],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:deleted, true],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['something_ignored']],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredBlock[['u', 'n', 'k', 'n', 'o', 'w', 'n'], []],
      Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['nested-host', []]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_SHARED_NETWORK)
  end

  def test_parse_pool
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128', [
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['pool', []]]]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 { pool {}}")
  end

  def test_parse_pool_with_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128', [
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['pool', [
        Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'next-server', [['x.x.x.x']]],
      ]]]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!("subnet 192.168.1.0 netmask 255.255.255.128 { pool { next-server x.x.x.x; }}")
  end

  MULTILINE_POOL =<<EOMULTILINE_POOL
    subnet 192.168.1.0 netmask 255.255.255.128 {
      pool {
        authoritative;
        range 192.168.1.1 192.168.1.100;
        filename "pxelinux.0";
        default-lease-time 86400;  # 1 Day
      }
    }
EOMULTILINE_POOL
  def test_parse_multiline_pool
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode['192.168.1.0', '255.255.255.128', [
      Proxy::DHCP::CommonISC::ConfigurationParser::GroupNode['pool', [
        Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['authoritative']],
        Proxy::DHCP::CommonISC::ConfigurationParser::RangeNode['192.168.1.1', '192.168.1.100', false],
        Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'filename', [['"pxelinux.0"']]],
        Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['default-lease-time', '86400']],
        Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['# 1 Day'],
      ]]]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_POOL)
  end

  def test_empty_host_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', []]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { }')
  end

  def test_deleted_host_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:deleted, true]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { deleted; }')
  end

  def test_dynamic_host_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:dynamic, true]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { dynamic; }')
  end

  def test_host_parser_with_hardware
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['ethernet', '01:02:03:04:05:06']
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { hardware ethernet 01:02:03:04:05:06; }')
  end

  def test_host_parser_with_fixed_address
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:fixed_address, '192.168.1.1']
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { fixed-address 192.168.1.1; }')
  end

  def test_host_parser_with_option
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"testing.test"']]]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { option domain-name "testing.test"; }')
  end

  def test_host_parser_with_comment
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['#a comment']
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(%[
      host testing { #a comment
      }
    ])
  end

  def test_host_parser_with_ignored_statement
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['unknown', 'statement']]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { unknown statement; }')
  end

  def test_host_parser_with_ignored_block
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredBlock[['u', 'n', 'k', 'n', 'o', 'w', 'n'], []]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('host testing { unknown {} }')
  end

  MULTILINE_HOST =<<EOMULTILINE_HOST
    host testing {
      hardware token-ring 01:02:03:04:05:06;
      fixed-address 192.168.1.1;
      option domain-name "testing.test";
      option routers 204.254.239.1;
      filename "pxelinux.0";
    }
EOMULTILINE_HOST
  def test_multiline_host_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::HostNode['testing', [
      Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['token-ring', '01:02:03:04:05:06'],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:fixed_address, '192.168.1.1'],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'domain-name', [['"testing.test"']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'routers', [['204.254.239.1']]],
      Proxy::DHCP::CommonISC::ConfigurationParser::OptionNode[false, 'filename', [['"pxelinux.0"']]]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_HOST)
  end

  def test_lease_timestamp_parser
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:starts, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('starts 2 2017/05/01 14:20:25;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:starts, Time.at(1_493_734_390).utc],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('starts epoch 1493734390;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:ends, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('ends 2 2017/05/01 14:20:25;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:ends, 'never'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('ends never;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:tstp, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('tstp 2 2017/05/01 14:20:25;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:tsfp, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('tsfp 2 2017/05/01 14:20:25;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:atsfp, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('atsfp 2 2017/05/01 14:20:25;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:cltt, Time.parse('2 2017/05/01 14:20:25 UTC')],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_time_stamp.parse!('cltt 2 2017/05/01 14:20:25;')
  end

  def test_lease_binding_state
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:binding_state, 'active'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_binding_state.parse!('binding state active;')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:binding_state, 'active'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_binding_state.parse!('binding state active ; ')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:next_binding_state, 'free'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_binding_state.parse!('next binding state free;')
  end

  def test_lease_uid
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:uid, '"\000DELLX\000\020W\200L\310\300O022"'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_uid.parse!('uid "\000DELLX\000\020W\200L\310\300O022";')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:uid, '"\000DELLX\000\020W\200L\310\300O022"'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_uid.parse!('uid "\000DELLX\000\020W\200L\310\300O022" ; ')
  end

  def test_lease_client_name
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:client_hostname, '"testing.test"'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_hostname.parse!('client-hostname "testing.test";')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:client_hostname, '"testing.test"'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_hostname.parse!('client-hostname "testing.test" ; ')
    assert_equal Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:client_hostname, 'testing.test'],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.lease_hostname.parse!('client-hostname testing.test; ')
  end

  def test_lease_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::LeaseNode['192.168.1.1', []]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('lease 192.168.1.1 { }')
  end

  MULTILINE_LEASE =<<OFMULTILNE_LEASE
  lease 192.168.10.1 {
    starts 2 2017/05/01 14:20:25;
    ends 2 2017/05/01 16:20:25;
    cltt 2 2017/05/01 14:20:25;
    binding state active;
    next binding state free;
    hardware ethernet ec:f4:bb:c6:ca:fe;
    client-hostname "testing";
    uid "123";
    # a comment
    something_ignored;
    ignored {
    }
  }
OFMULTILNE_LEASE
  def test_multiline_lease_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::LeaseNode['192.168.10.1', [
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:starts, Time.parse('2 2017/05/01 14:20:25 UTC')],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:ends, Time.parse('2 2017/05/01 16:20:25 UTC')],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:cltt, Time.parse('2 2017/05/01 14:20:25 UTC')],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:binding_state, 'active'],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:next_binding_state, 'free'],
      Proxy::DHCP::CommonISC::ConfigurationParser::HardwareNode['ethernet', 'ec:f4:bb:c6:ca:fe'],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:client_hostname, '"testing"'],
      Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:uid, '"123"'],
      Proxy::DHCP::CommonISC::ConfigurationParser::CommentNode['# a comment'],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredDeclaration[['something_ignored']],
      Proxy::DHCP::CommonISC::ConfigurationParser::IgnoredBlock[['i', 'g', 'n', 'o', 'r', 'e', 'd'], []]
    ]]], Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!(MULTILINE_LEASE)
  end

  def test_server_duid_parser
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, '"\000\001\000\001!:}\221RT\000^\244\022"']],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid "\000\001\000\001!:}\221RT\000^\244\022";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, "\"\\000\\001\\000\\001!\\374\\304\\243\\000PV\\244\\350{\""]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid "\000\001\000\001!\374\304\243\000PV\244\350{";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, '00:01:00:01:1e:68:b3:db:0a:00:27:00:00:02']],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid 00:01:00:01:1e:68:b3:db:0a:00:27:00:00:02;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, ['llt']]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid llt;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, ['llt', 'ethernet', '213982198', '00:16:6F:49:7D:9B']]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid llt ethernet 213982198 00:16:6F:49:7D:9B;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, ['ll']]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid ll;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, ['ll', 'fddi', '00:16:6F:49:7D:9B']]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid ll fddi 00:16:6F:49:7D:9B;')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, ['en', 2495, '"enterprise-specific-identifier-1234"']]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid en 2495 "enterprise-specific-identifier-1234";')
    assert_equal [Proxy::DHCP::CommonISC::ConfigurationParser::KeyValueNode[:server_duid, 1234]],
                 Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('server-duid 1234;')
  end

  def test_ignored_declaration_parser
    Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('aaa true;')
  end

  def test_ignored_block_parser
    Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('aaa bbb { fff true; }')
  end

  def test_include
    included = Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('include "test/fixtures/dhcp/dhcp_subnets.conf";').flatten
    assert_equal ['192.168.122.0', '192.168.123.0', '192.168.124.0', '192.168.1.0'],
                 included.select {|node| node.class == Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode}.map(&:subnet_address)
    assert_equal ['test.example.com'],
                 included.select {|node| node.class == Proxy::DHCP::CommonISC::ConfigurationParser::HostNode}.map(&:fqdn)
  end

  def test_include_in_shared_network
    included =
      Proxy::DHCP::CommonISC::ConfigurationParser.new.conf.parse!('shared-network "testing" {include "test/fixtures/dhcp/dhcp_subnets.conf";}')
    assert_equal 1, included.size
    assert_equal ['192.168.122.0', '192.168.123.0', '192.168.124.0', '192.168.1.0'],
                 included.first.options_and_settings.flatten.select {|node| node.class == Proxy::DHCP::CommonISC::ConfigurationParser::IpV4SubnetNode}.map(&:subnet_address)
    assert_equal ['test.example.com'],
                 included.first.options_and_settings.flatten.select {|node| node.class == Proxy::DHCP::CommonISC::ConfigurationParser::HostNode}.map(&:fqdn)
  end
end
