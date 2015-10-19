require 'test_helper'
require 'dns_virsh/dns_virsh_plugin'
require 'dns_virsh/dns_virsh_main'

class DnsVirshTest < Test::Unit::TestCase
  def test_virsh_provider_initialization
    ::Proxy::SETTINGS.stubs(:virsh_network).returns('some_network')
    server = Proxy::Dns::Virsh::Record.new
    assert_equal "some_network", server.network
  end

  def test_virsh_entry_not_exists_returns_proxy_dns_notfound
    Proxy::Dns::Virsh::Record.any_instance.stubs(:dump_xml).returns('<network><name>default</name></network>')
    server = Proxy::Dns::Virsh::Record.new('default')
    assert_raise Proxy::Dns::NotFound do
      server.remove_a_record('not_existing.example.com')
    end
  end

  def test_virsh_removes_existing_entry
    xml_response = <<XMLRESPONSE
<network>
  <name>default</name>
  <domain name='local.lan'/>
  <dns>
    <host ip='127.13.0.2'>
      <hostname>not_existing.example.com</hostname>
    </host>
  </dns>
  <ip address='127.13.0.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='127.13.0.2' end='127.13.0.100'/>
      <host mac='52:54:00:e2:62:08' name='not_existing.example.com' ip='127.13.0.2'/>
    </dhcp>
  </ip>
</network>
XMLRESPONSE
    Proxy::Dns::Virsh::Record.any_instance.stubs(:dump_xml).returns(xml_response)
    server = Proxy::Dns::Virsh::Record.new("default")
    server.expects(:escape_for_shell).at_least(2).returns(true)
    server.expects(:virsh).returns('Updated')
    assert server.remove_a_record('not_existing.example.com')
  end
end
