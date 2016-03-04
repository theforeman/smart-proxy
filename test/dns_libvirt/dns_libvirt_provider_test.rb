require 'test_helper'
require 'dns_libvirt/dns_libvirt_plugin'
require 'dns_libvirt/dns_libvirt_main'

class DnsLibvirtProviderTest < Test::Unit::TestCase
  def setup
    fixture = <<XMLFIXTURE
<network>
  <name>default</name>
  <domain name='local.lan'/>
  <dns>
    <host ip='192.168.122.1'>
      <hostname>some.example.com</hostname>
    </host>
  </dns>
  <ip address='192.168.122.0' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.1' end='192.168.122.250'/>
      <host mac='52:54:00:e2:62:08' name='some.example.com' ip='192.168.122.1'/>
    </dhcp>
  </ip>
</network>
XMLFIXTURE
    @libvirt_network = mock()
    @libvirt_network.stubs(:dump_xml).returns(fixture)
    @subject = Proxy::Dns::Libvirt::Record.new(
      :libvirt_network => @libvirt_network
    )
  end

  def test_default_settings
    ::Proxy::Dns::Libvirt::Plugin.load_test_settings({})
    assert_equal 'default', Proxy::Dns::Libvirt::Plugin.settings.network
  end

  def test_provider_initialization
    ::Proxy::Dns::Libvirt::Plugin.load_test_settings(:network => 'some_network')
    assert_equal "some_network", Proxy::Dns::Libvirt::Record.new(:libvirt_network => @libvirt_network).network
  end

  def test_libvirt_network_class
    assert_equal ::Proxy::Dns::Libvirt::LibvirtDNSNetwork, ::Proxy::Dns::Libvirt::Record.new.libvirt_network.class
  end

  def test_add_a_record
    fqdn = "abc.example.com"
    ip = "192.168.122.2"
    @subject.libvirt_network.expects(:add_dns_a_record).with(fqdn, ip)
    @subject.create_a_record(fqdn, ip)
  end

  def test_del_a_record
    fqdn = "abc.example.com"
    ip = "192.168.122.2"
    @subject.expects(:find_ip_for_host).with(fqdn).returns(ip)
    @subject.libvirt_network.expects(:del_dns_a_record).with(fqdn, ip)
    @subject.remove_a_record(fqdn)
  end

  def test_add_aaaa_record
    fqdn = "abc6.example.com"
    ip = "2001:db8:85a3:0:0:8a2e:370:7334"
    @subject.libvirt_network.expects(:add_dns_a_record).with(fqdn, ip)
    @subject.create_a_record(fqdn, ip)
  end

  def test_del_aaaa_record
    fqdn = "abc6.example.com"
    ip = "2001:db8:85a3:0:0:8a2e:370:7334"
    @subject.expects(:find_ip_for_host).with(fqdn).returns(ip)
    @subject.libvirt_network.expects(:del_dns_a_record).with(fqdn, ip)
    @subject.remove_a_record(fqdn)
  end

  def test_del_a_record_failure
    assert_raise Proxy::Dns::NotFound do
      @subject.remove_a_record('does_not_exist')
    end
  end
end
