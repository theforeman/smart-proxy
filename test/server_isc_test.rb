require 'test_helper'
require 'helpers'
require 'json'
require 'proxy/dhcp'
require 'proxy/dhcp/server'
require 'proxy/dhcp/server/isc'
require 'dhcp_api'

ENV['RACK_ENV'] = 'test'

class ServerIscTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def test_sparc_host
    data = {
      "hostname"=>"itgsyddev910.macbank",
      "mac"=>"00:21:28:6d:62:e8",
      "ip"=>"192.168.122.11",
      "network"=>"192.168.122.0",
      "nextServer"=>"192.168.122.24",
      "filename"=>"Solaris-5.10-hw0811-sun4v-inetboot",
      "<SPARC-Enterprise-T5120>root_path_name"=>"/Solaris/install/Solaris_5.10_sparc_hw0811/Solaris_10/Tools/Boot",
      "<SPARC-Enterprise-T5120>sysid_server_path"=>"192.168.122.24:/Solaris/jumpstart/sysidcfg/sysidcfg_primary",
      "<SPARC-Enterprise-T5120>install_server_ip"=>"192.168.122.24",
      "<SPARC-Enterprise-T5120>jumpstart_server_path"=>"192.168.122.24:/Solaris/jumpstart",
      "<SPARC-Enterprise-T5120>install_server_name"=>"itgsyddev807.macbank",
      "<SPARC-Enterprise-T5120>root_server_hostname"=>"itgsyddev807.macbank",
      "<SPARC-Enterprise-T5120>root_server_ip"=>"192.168.122.24",
      "<SPARC-Enterprise-T5120>install_path"=>"/Solaris/install/Solaris_5.10_sparc_hw0811"
    }
    s=Proxy::DHCP::Server.new('192.168.122.1')
    sub=Proxy::DHCP::Subnet.new(s,'192.168.122.0','255.255.255.0')
    Proxy::DHCP::Server::ISC.any_instance.stubs(:find_subnet).returns(sub)
    post '/dhcp/192.168.122.10', data
    assert last_response.ok?, 'Last response was not ok'
  end

  def test_ztp_quirks
    dhcp = Proxy::DHCP::Server::ISC.new(:name => '192.168.122.1', :config => './test/dhcp.conf', :leases => './test/dhcp.leases')
    assert_equal [], dhcp.send(:ztp_options_statements, {})
    assert_equal [], dhcp.send(:ztp_options_statements, {:filename => 'foo.cfg'})

    assert_equal ['option option-150 = c0:a8:7a:01;', 'option FM_ZTP.config-file-name = \\"ztp.cfg\\";'],
      dhcp.send(:ztp_options_statements, {:filename => 'ztp.cfg', :nextServer => '192.168.122.1'})
  end
end
