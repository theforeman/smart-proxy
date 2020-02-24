require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'
require 'dhcp_common/record/lease'
require 'dhcp_common/record/reservation'
require 'dhcp_common/isc/configuration_parser'
require 'dhcp_common/isc/subnet_service_initialization'

class DhcpIscSubnetServiceInitializationTest < Test::Unit::TestCase
  DHCPD_CONFIG =<<END
# This is a comment.

omapi-port 7911;
default-lease-time 43200;
max-lease-time 86400;
ddns-update-style none;
option domain-name "some.example.com";
option domain-name-servers 192.168.121.101;
option ntp-servers none;
allow booting;
allow bootp;
option fqdn.no-client-update on;
option fqdn.rcode2 255;
option pxegrub code 150 = text ;

option voip-tftp-server code 150 = { ip-address };

subnet 192.168.122.0 netmask 255.255.255.0 {
  option interface-mtu 9000;
  option voip-tftp-server 1.2.3.4;
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
    @subnet_service = Proxy::DHCP::SubnetService.initialized_instance
    @parser = ::Proxy::DHCP::CommonISC::ConfigurationParser.new
    @initialization = ::Proxy::DHCP::CommonISC::IscSubnetServiceInitialization.new(@subnet_service, @parser)
  end

  def test_load_subnets_loads_managed_subnets
    @initialization.load_configuration_file(DHCPD_CONFIG)
    assert_equal 4, @subnet_service.all_subnets.size
  end

  def test_managed_subnets_network_addresses
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal "192.168.122.0", subnets[0].network
    assert_equal "192.168.123.0", subnets[1].network
    assert_equal "192.168.124.0", subnets[2].network
    assert_equal "192.168.1.0", subnets[3].network
  end

  def test_interface_mtu_option
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal 9000, subnets[0].options[:interface_mtu]
  end

  def test_managed_subnets_netmask
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal "255.255.255.0", subnets[0].netmask
    assert_equal "255.255.255.192", subnets[1].netmask
    assert_equal "255.255.255.0", subnets[2].netmask
    assert_equal "255.255.255.128", subnets[3].netmask
  end

  def test_managed_subnets_router_addresses
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal ["192.168.122.250"], subnets[0].options[:routers]
    assert_equal nil, subnets[0].options[:routers][1]
    assert_equal ["192.168.123.1"], subnets[1].options[:routers]
    assert_equal ["192.168.124.1", "192.168.124.2"], subnets[2].options[:routers]
  end

  def test_managed_subnets_domain_name_servers
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal nil, subnets[0].options[:domain_name_servers]
    assert_equal ["192.168.123.1"], subnets[1].options[:domain_name_servers]
    assert_equal ["192.168.123.1", "192.168.122.250"], subnets[2].options[:domain_name_servers]
  end

  def test_managed_subnets_range
    @initialization.load_configuration_file(DHCPD_CONFIG)
    subnets = @subnet_service.all_subnets
    assert_equal nil, subnets[0].options[:range]
    assert_equal ["192.168.123.2", "192.168.123.62"], subnets[1].options[:range]
    assert_equal nil, subnets[2].options[:range]
  end

  def test_parse_config_and_leases
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))
    parsed = @subnet_service.all_hosts + @subnet_service.all_leases

    assert_equal 12, parsed.size
    assert_equal 'bravo.example.com', @subnet_service.find_host_by_hostname("bravo2.example.com").hostname
  end

  def test_parsing_and_loading_deleted_host
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))

    assert_nil @subnet_service.find_host_by_hostname("deleted.example.com")
  end

  def test_parsing_and_loading_undeleted_host
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))

    assert_not_nil @subnet_service.find_host_by_hostname("undeleted.example.com")
  end

  def test_host_with_duplicate_mac_address_is_removed
    @subnet_service.add_subnet(subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @subnet_service.add_host("192.168.0.0", ::Proxy::DHCP::Reservation.new("test", "192.168.0.10", "00:11:22:33:44:55", subnet))
    @initialization.load_leases_file("host testing { fixed-address 192.168.0.11; hardware ethernet 00:11:22:33:44:55; }")

    assert_equal "192.168.0.11", @subnet_service.find_host_by_mac("192.168.0.0", "00:11:22:33:44:55").ip
  end

  def test_parsing_and_loading_bonded_hosts
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))

    assert_equal 'bond.example.com', @subnet_service.find_host_by_hostname("bond.example.com-01").hostname
    assert_equal 'bond.example.com', @subnet_service.find_host_by_hostname("bond.example.com-02").hostname
    assert_equal 2, @subnet_service.find_hosts_by_ip("192.168.122.0", "192.168.122.43").size
  end

  def test_host_creation_with_hostname_option_present
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))
    assert_equal 'bravo.example.com', @subnet_service.find_host_by_hostname("bravo2.example.com").hostname
  end

  def test_dynamic_host_should_be_deleteable
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))
    assert_equal true, @subnet_service.find_host_by_hostname("bravo2.example.com").deleteable?
  end

  def test_static_host_should_not_be_deleteable
    subnet = Proxy::DHCP::Subnet.new("192.168.122.0", "255.255.255.0")
    @subnet_service.add_subnet(subnet)
    @initialization.load_leases_file(File.read("./test/fixtures/dhcp/dhcp.leases"))
    assert_equal false, @subnet_service.find_host_by_hostname("static.example.com").deleteable?
  end

  def test_parsing_and_loading_leases
    @subnet_service.add_subnet(Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @initialization.load_leases_file(%[
    lease 192.168.0.1 {
      hardware ethernet 00:11:22:33:44:55;
      starts 2 2017/05/02 12:53:16;
      ends 2 2017/05/02 13:03:16;
      cltt 2 2017/05/02 12:53:16;
      binding state active;
    }])
    assert_equal "192.168.0.1", @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55").ip
  end

  def test_should_delete_free_lease
    @subnet_service.add_subnet(subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @subnet_service.add_lease('192.168.0.0', ::Proxy::DHCP::Lease.new('test', "192.168.0.1", "00:11:22:33:44:55", subnet, nil, nil, nil))
    @initialization.load_leases_file(%[
    lease 192.168.0.1 {
      hardware ethernet 00:11:22:33:44:55;
      binding state free;
    }])
    assert_nil @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55")
  end

  def timestamp(offset = 0)
    t = (Time.now + offset).utc
    t.strftime "%u %Y/%m/%d %H:%M:%S"
  end

  def test_should_delete_expired_leases
    @subnet_service.add_subnet(subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @subnet_service.add_lease('192.168.0.0', ::Proxy::DHCP::Lease.new('test', "192.168.0.1", "00:11:22:33:44:55", subnet, nil, nil, nil))
    @initialization.load_leases_file(%[
    lease 192.168.0.1 {
      hardware ethernet 00:11:22:33:44:55;
      starts #{timestamp(-120)};
      ends #{timestamp(-1)};
      next binding state free;
    }])
    assert_nil @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55")
  end

  def test_should_delete_leases_with_duplicate_mac_addresses
    @subnet_service.add_subnet(subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @subnet_service.add_lease('192.168.0.0', ::Proxy::DHCP::Lease.new('test', "192.168.0.1", "00:11:22:33:44:55", subnet, nil, nil, nil))
    @initialization.load_leases_file(%[
    lease 192.168.0.2 {
      hardware ethernet 00:11:22:33:44:55;
      starts #{timestamp(-60)};
      ends #{timestamp(60)};
      binding state active;
      next binding state free;
    }])
    assert_equal "192.168.0.2", @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55").ip
  end

  def test_should_delete_leases_with_duplicate_ip_addresses
    @subnet_service.add_subnet(subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    @subnet_service.add_lease('192.168.0.0', ::Proxy::DHCP::Lease.new('test', "192.168.0.1", "00:11:22:33:44:55", subnet, nil, nil, nil))
    @initialization.load_leases_file(%[
    lease 192.168.0.1 {
      hardware ethernet 00:11:22:33:44:66;
      starts #{timestamp(-60)};
      ends #{timestamp(60)};
      binding state active;
      next binding state free;
    }])
    assert_nil @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55")
    assert_equal "192.168.0.1", @subnet_service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:66").ip
  end

  def test_routers_option_conversion
    assert_equal [:routers, ["192.168.1.1", "192.168.1.2"]], @initialization.process_dhcpd_option('routers', [["192.168.1.1"], ["192.168.1.2"]])
    assert_equal [:routers, ["192.168.1.1", "192.168.1.2"]], @initialization.process_dhcpd_option('routers', [["\"192.168.1.1\""], ["\"192.168.1.2\""]])
  end

  def test_domain_name_servers_option_conversion
    assert_equal [:domain_name_servers, ["192.168.1.1"]], @initialization.process_dhcpd_option('domain-name-servers', [["192.168.1.1"]])
    assert_equal [:domain_name_servers, ["192.168.1.1", "192.168.1.2"]], @initialization.process_dhcpd_option('domain-name-servers', [["192.168.1.1"], ["192.168.1.2"]])
    assert_equal [:domain_name_servers, ["a.b.c", "a.b.d"]], @initialization.process_dhcpd_option('domain-name-servers', [["\"a.b.c\""], ["\"a.b.d\""]])
  end

  def test_next_server_option_conversion
    assert_equal [:nextServer, "192.168.1.1"], @initialization.process_dhcpd_option('next-server', [["192.168.1.1"]])
    assert_equal [:nextServer, "192.168.1.1"], @initialization.process_dhcpd_option('next-server', [["\"192.168.1.1\""]])
    assert_equal [:nextServer, "192.168.1.1"], @initialization.process_dhcpd_option('server.next-server', [["192.168.1.1"]])
    assert_equal [:nextServer, "192.168.0.1"], @initialization.process_dhcpd_option('next-server', [["c0:a8:00:01"]])
  end

  def test_filename_option_conversion
    assert_equal [:filename, "pxelinux.0"], @initialization.process_dhcpd_option('filename', [["\"pxelinux.0\""]])
    assert_equal [:filename, "pxelinux.0"], @initialization.process_dhcpd_option('server.filename', [["\"pxelinux.0\""]])
  end

  def test_hostname_option_conversion
    assert_equal [:hostname, "a.b.c"], @initialization.process_dhcpd_option('host-name', [["\"a.b.c\""]])
  end

  def test_sunw_root_server_ip_address_option_conversion
    assert_equal [:root_server_ip, "192.168.1.1"], @initialization.process_dhcpd_option('SUNW.root-server-ip-address', [["192.168.1.1"]])
    assert_equal [:root_server_ip, "192.168.1.1"], @initialization.process_dhcpd_option('SUNW.root-server-ip-address', [["\"192.168.1.1\""]])
  end

  def test_sunw_root_server_hostname_option_conversion
    assert_equal [:root_server_hostname, "a.b.c"], @initialization.process_dhcpd_option('SUNW.root-server-hostname', [["a.b.c"]])
    assert_equal [:root_server_hostname, "a.b.c"], @initialization.process_dhcpd_option('SUNW.root-server-hostname', [["\"a.b.c\""]])
  end

  def test_sunw_root_path_name_option_conversion
    assert_equal [:root_path_name, "a/b/c"], @initialization.process_dhcpd_option('SUNW.root-path-name', [["a/b/c"]])
    assert_equal [:root_path_name, "a/b/c"], @initialization.process_dhcpd_option('SUNW.root-path-name', [["\"a/b/c\""]])
  end

  def test_sunw_install_server_ip_address_option_conversion
    assert_equal [:install_server_ip, "192.168.1.1"], @initialization.process_dhcpd_option('SUNW.install-server-ip-address', [["192.168.1.1"]])
    assert_equal [:install_server_ip, "192.168.1.1"], @initialization.process_dhcpd_option('SUNW.install-server-ip-address', [["\"192.168.1.1\""]])
  end

  def test_sunw_install_server_hostname_option_conversion
    assert_equal [:install_server_name, "a.b.c"], @initialization.process_dhcpd_option('SUNW.install-server-hostname', [["a.b.c"]])
    assert_equal [:install_server_name, "a.b.c"], @initialization.process_dhcpd_option('SUNW.install-server-hostname', [["\"a.b.c\""]])
  end

  def test_sunw_install_path_option_conversion
    assert_equal [:install_path, "a/b/c"], @initialization.process_dhcpd_option('SUNW.install-path', [["a/b/c"]])
    assert_equal [:install_path, "a/b/c"], @initialization.process_dhcpd_option('SUNW.install-path', [["\"a/b/c\""]])
  end

  def test_sunw_sysid_config_file_server_option_conversion
    assert_equal [:sysid_server_path, "192.168.1.1:/export/home/jumpstart/configs/sysids/web"],
                 @initialization.process_dhcpd_option('SUNW.sysid-config-file-server', [["192.168.1.1:/export/home/jumpstart/configs/sysids/web"]])
    assert_equal [:sysid_server_path, "192.168.1.1:/export/home/jumpstart/configs/sysids/web"],
                 @initialization.process_dhcpd_option('SUNW.sysid-config-file-server', [["\"192.168.1.1:/export/home/jumpstart/configs/sysids/web\""]])
  end

  def test_sunw_jumpstart_server_option_conversion
    assert_equal [:jumpstart_server_path, "192.168.1.1:/export/home/jumpstart/configs/sysids/web"],
                 @initialization.process_dhcpd_option('SUNW.JumpStart-server', [["192.168.1.1:/export/home/jumpstart/configs/sysids/web"]])
    assert_equal [:jumpstart_server_path, "192.168.1.1:/export/home/jumpstart/configs/sysids/web"],
                 @initialization.process_dhcpd_option('SUNW.JumpStart-server', [["\"192.168.1.1:/export/home/jumpstart/configs/sysids/web\""]])
  end

  def test_unknown_option_conversion
    assert_equal [:a_b_c, [["something"], ["or"], ["another"]]], @initialization.process_dhcpd_option('a-b-c', [["something"], ["or"], ["another"]])
    assert_equal [:a_b_c, [["something"], ["or"], ["another"]]], @initialization.process_dhcpd_option('a-b-c', [["\"something\""], ["\"or\""], ["\"another\""]])
  end
end
