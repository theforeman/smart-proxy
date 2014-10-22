require 'test_helper'
require 'dns/dns'
require 'dns/providers/nsupdate'
require 'dns/providers/virsh'

class DnsUpdateTest < Test::Unit::TestCase

  def test_nsupdate_entry_not_exist_returns_proxy_dns_notfound
    Proxy::Dns::Plugin.settings.stubs(:dns_key).returns(nil)
    Proxy::Dns::Nsupdate.any_instance.stubs(:nsupdate).returns(true)
    Resolv::DNS.any_instance.stubs(:getaddress).raises(Resolv::ResolvError.new('DNS result has no information'))
    Resolv::DNS.any_instance.stubs(:getaname).raises(Resolv::ResolvError.new('DNS result has no information'))
    server = Proxy::Dns::Nsupdate.new(:fqdn => 'not_existing.example.com')
    assert_raise Proxy::Dns::NotFound do
      server.remove
    end
  end

  def test_virsh_entry_not_exists_returns_proxy_dns_notfound
    Proxy::Dns::Virsh.any_instance.stubs(:dump_xml).returns('<network><name>default</name></network>')
    server = Proxy::Dns::Virsh.new(:fqdn=>'not_existing.example.com', :value=>'127.13.0.2',
                                    :type=>'A', :virsh_network=>'default')
    assert_raise Proxy::Dns::NotFound do
      server.remove
    end
  end

  def test_nsupdate_removes_existing_entry
    Proxy::Dns::Plugin.settings.stubs(:dns_key).returns(nil)
    Proxy::Dns::Nsupdate.any_instance.stubs(:nsupdate).returns(true)
    Resolv::DNS.any_instance.stubs(:getaddress).returns('127.13.0.2')
    Resolv::DNS.any_instance.stubs(:getaname).returns('not_existing.example.com')
    server = Proxy::Dns::Nsupdate.new(:fqdn => 'not_existing.example.com')
    assert server.remove
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
    Proxy::Dns::Virsh.any_instance.stubs(:dump_xml).returns(xml_response)
    server = Proxy::Dns::Virsh.new(:fqdn=>'not_existing.example.com', :value=>'127.13.0.2',
                                    :type=>'A', :virsh_network=>'default')
    server.expects(:escape_for_shell).at_least(2).returns(true)
    server.expects(:virsh).returns('Updated')
    assert server.remove
  end
end
