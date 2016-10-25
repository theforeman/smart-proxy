require 'test_helper'
require 'dns_common/dns_common'

class DnsRecordTest < Test::Unit::TestCase
  def test_dns_find_with_ip_parameter
    Resolv::DNS.any_instance.expects(:getname).with('127.13.0.2').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.dns_find('2.0.13.127.in-addr.arpa')
  end

  def test_dns_find_with_ipv6_parameter
    Resolv::DNS.any_instance.expects(:getname).with('2001:0db8:deef:0000:0000:0000:0000:0001').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.dns_find('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_dns_find_with_fqdn_parameter
    Resolv::DNS.any_instance.expects(:getaddress).with('some.host').returns(ips('127.13.0.2'))
    assert '127.13.0.2', Proxy::Dns::Record.new.dns_find('some.host')
  end

  def test_get_name_with_sideeffect_for_ipv4
    Resolv::DNS.any_instance.expects(:getname).with('127.13.0.2').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.get_name!('2.0.13.127.in-addr.arpa')
  end

  def test_get_name_with_sideeffect_for_ipv6
    Resolv::DNS.any_instance.expects(:getname).with('2001:0db8:deef:0000:0000:0000:0000:0001').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.get_name!('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_get_name_with_sideeffect_raises_exception_when_ip_is_unknown
    Resolv::DNS.any_instance.expects(:getname).with('127.13.0.2').raises(Resolv::ResolvError)
    assert_raises(Proxy::Dns::NotFound) { Proxy::Dns::Record.new.get_name!('2.0.13.127.in-addr.arpa') }
  end

  def test_get_name_for_ipv4
    Resolv::DNS.any_instance.expects(:getname).with('127.13.0.2').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.get_name('2.0.13.127.in-addr.arpa')
  end

  def test_get_name_for_ipv6
    Resolv::DNS.any_instance.expects(:getname).with('2001:0db8:deef:0000:0000:0000:0000:0001').returns('not_existing.example.com')
    assert 'not_existing.example.com', Proxy::Dns::Record.new.get_name('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_get_name_with_unknown_ip
    Resolv::DNS.any_instance.expects(:getname).with('127.13.0.2').raises(Resolv::ResolvError)
    assert_equal false, Proxy::Dns::Record.new.get_name('2.0.13.127.in-addr.arpa')
  end

  def test_get_address_with_sideeffect
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '127.14.0.2'))
    assert '127.13.0.2', Proxy::Dns::Record.new.get_address!('some.host')
  end

  def test_get_address_with_sideeffect_raises_exception_when_fqdn_is_unknown
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').raises(Resolv::ResolvError)
    assert_raises(Proxy::Dns::NotFound) { Proxy::Dns::Record.new.get_address!('some.host') }
  end

  def test_get_address
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '127.14.0.2'))
    assert '127.13.0.2', Proxy::Dns::Record.new.get_address('some.host')
  end

  def test_get_address_with_unknown_fqdn
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').raises(Resolv::ResolvError)
    assert_equal false, Proxy::Dns::Record.new.get_address('some.host')
  end

  def test_get_ipv4_address_with_sideeffects
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '2A00:1450:400C:C04::6A'))
    assert '127.13.0.2', Proxy::Dns::Record.new.get_ipv4_address!('some.host')
  end

  def test_get_ipv4_address
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '2A00:1450:400C:C04::6A'))
    assert '127.13.0.2', Proxy::Dns::Record.new.get_ipv4_address('some.host')
  end

  def test_get_ipv4_address_with_sideeffects_when_no_ipv4_are_present
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('2A00:1450:400C:C04::6A'))
    assert_raises(Proxy::Dns::NotFound) { Proxy::Dns::Record.new.get_ipv4_address!('some.host') }
  end

  def test_get_ipv4_address_when_no_ipv4_are_present
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('2A00:1450:400C:C04::6A'))
    assert_equal false, Proxy::Dns::Record.new.get_ipv4_address('some.host')
  end

  def test_get_ipv6_address_with_sideeffects
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '2A00:1450:400C:C04::6A'))
    assert '2A00:1450:400C:C04::6A', Proxy::Dns::Record.new.get_ipv6_address!('some.host')
  end

  def test_get_ipv6_address
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2', '2A00:1450:400C:C04::6A'))
    assert '2A00:1450:400C:C04::6A', Proxy::Dns::Record.new.get_ipv6_address('some.host')
  end

  def test_get_ipv6_address_with_sideeffects_when_no_ipv6_are_present
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2'))
    assert_raises(Proxy::Dns::NotFound) { Proxy::Dns::Record.new.get_ipv6_address!('some.host') }
  end

  def test_get_ipv6_address_when_no_ipv6_are_present
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('127.13.0.2'))
    assert_equal false, Proxy::Dns::Record.new.get_ipv6_address('some.host')
  end

  def test_dns_find_key_not_found
    Resolv::DNS.any_instance.expects(:getaddress).with('another.host').raises(Resolv::ResolvError.new('DNS result has no information'))
    assert !Proxy::Dns::Record.new.dns_find('another.host')
  end

  def test_ptr_to_ip_ipv4
    assert_equal('192.168.33.30', Proxy::Dns::Record.new.ptr_to_ip('30.33.168.192.in-addr.arpa'))
  end

  def test_ptr_to_ip_ipv6
    assert_equal('2001:0db8:deef:0000:0000:0000:0000:0001', Proxy::Dns::Record.new.ptr_to_ip('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa'))
  end

  def test_ptr_to_ip_without_record_exception
    assert_raise Proxy::Dns::Error do
      Proxy::Dns::Record.new.ptr_to_ip('host.example.com')
    end
  end

  def test_a_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns([])
    assert_equal -1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_a_record_conflicts_no_conflict_with_ipv6
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('2001:DB8:DEEF::1'))
    assert_equal -1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_a_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33', '2001:DB8:DEEF::1'))
    assert_equal 1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.11.11')
  end

  def test_a_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33', '2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_aaaa_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns([])
    assert_equal -1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_aaaa_record_conflicts_no_conflict_with_ipv4
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33'))
    assert_equal -1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_aaaa_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33', '2001:DB8:DEEF::1'))
    assert_equal 1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:ABCD::1')
  end

  def test_aaaa_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33', '2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_ptr_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getnames).with('192.168.33.33').returns([])
    assert_equal -1, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '192.168.33.33')
  end

  def test_ptr_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getnames).with('2001:db8:deef::1').returns(['some.host'])
    assert_equal 1, Proxy::Dns::Record.new.ptr_record_conflicts('another.host', '2001:db8:deef::1')
  end

  def test_ptr_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getnames).with('192.168.33.33').returns(['some.host'])
    assert_equal 0, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '192.168.33.33')
  end

  def test_aaaa_record_conflicts_is_case_insensetive
    Resolv::DNS.any_instance.expects(:getaddresses).with('some.host').returns(ips('192.168.33.33', '2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:db8:deef::1')
  end

  def test_validate_ip
    assert_equal '192.168.33.33', Proxy::Dns::Record.new.to_ipaddress('192.168.33.33').to_s
    assert_equal '2001:db8:deef::1', Proxy::Dns::Record.new.to_ipaddress('2001:db8:deef::1').to_s
    assert_equal false, Proxy::Dns::Record.new.to_ipaddress('some.host')
  end

  def ips(*ips)
    ips.map {|ip| ip =~  Resolv::IPv4::Regex ? Resolv::IPv4.create(ip) : Resolv::IPv6.create(ip) }
  end
end
