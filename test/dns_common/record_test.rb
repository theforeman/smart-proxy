require 'test_helper'
require 'dns_common/dns_common'

class DnsRecordTest < Test::Unit::TestCase
  def test_dns_find_with_ip_parameter
    Resolv::DNS.any_instance.expects(:getname).with('2.0.13.127').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.dns_find('127.13.0.2')
  end

  def test_dns_find_with_fqdn_parameter
    Resolv::DNS.any_instance.expects(:getaddress).with('some.host').returns('127.13.0.2')
    assert '127.13.0.2', Proxy::Dns::Record.new.dns_find('some.host')
  end

  def test_dns_find_key_not_found
    Resolv::DNS.any_instance.expects(:getaddress).with('another.host').raises(Resolv::ResolvError.new('DNS result has no information'))
    assert !Proxy::Dns::Record.new.dns_find('another.host')
  end
end
