require 'test_helper'
require 'dns_common/dns_common'

class DnsRecordTest < Test::Unit::TestCase
  def setup
    @record = Proxy::Dns::Record.new
  end

  def test_dns_find_with_ip_parameter
    @record.expects(:get_name).with('2.0.13.127.in-addr.arpa').returns('not_existing.example.com')
    assert_equal 'not_existing.example.com', @record.dns_find('2.0.13.127.in-addr.arpa')
  end

  def test_dns_find_with_ipv6_parameter
    @record.expects(:get_name).with('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa').returns('not_existing.example.com')
    assert_equal 'not_existing.example.com', @record.dns_find('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_dns_find_with_fqdn_parameter
    Resolv::DNS.any_instance.expects(:getaddress).with('some.host').returns(Resolv::IPv4.create('127.13.0.2'))
    assert_equal '127.13.0.2', Proxy::Dns::Record.new.dns_find('some.host')
  end

  def test_get_name_with_sideeffect_for_ipv4
    @record.expects(:get_resource_as_string!).with('2.0.13.127.in-addr.arpa', Resolv::DNS::Resource::IN::PTR, :name).returns('not_existing.example.com')
    assert 'not_existing.example.com', @record.get_name!('2.0.13.127.in-addr.arpa')
  end

  def test_get_name_with_sideeffect_for_ipv6
    @record.expects(:get_resource_as_string!).with('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa', Resolv::DNS::Resource::IN::PTR, :name).returns('not_existing.example.com')
    assert 'not_existing.example.com', @record.get_name!('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_get_name_for_ipv4
    @record.expects(:get_resource_as_string).with('2.0.13.127.in-addr.arpa', Resolv::DNS::Resource::IN::PTR, :name).returns('not_existing.example.com')
    assert 'not_existing.example.com', @record.get_name('2.0.13.127.in-addr.arpa')
  end

  def test_get_name_for_ipv6
    @record.expects(:get_resource_as_string).with('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa', Resolv::DNS::Resource::IN::PTR, :name).returns('not_existing.example.com')
    assert 'not_existing.example.com', @record.get_name('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_get_ipv4_address_with_sideeffects
    @record.expects(:get_resource_as_string!).with('some.host', Resolv::DNS::Resource::IN::A, :address).returns('127.13.0.2')
    assert '127.13.0.2', @record.get_ipv4_address!('some.host')
  end

  def test_get_ipv4_address
    @record.expects(:get_resource_as_string).with('some.host', Resolv::DNS::Resource::IN::A, :address).returns('127.13.0.2')
    assert '127.13.0.2', @record.get_ipv4_address('some.host')
  end

  def test_get_ipv6_address_with_sideeffects
    @record.expects(:get_resource_as_string!).with('some.host', Resolv::DNS::Resource::IN::AAAA, :address).returns('2A00:1450:400C:C04::6A')
    assert '2A00:1450:400C:C04::6A', @record.get_ipv6_address!('some.host')
  end

  def test_get_ipv6_address
    @record.expects(:get_resource_as_string).with('some.host', Resolv::DNS::Resource::IN::AAAA, :address).returns('2A00:1450:400C:C04::6A')
    assert '2A00:1450:400C:C04::6A', @record.get_ipv6_address('some.host')
  end

  def test_get_resource_as_string_with_sideeffects
    Resolv::DNS.any_instance.expects(:getresource).with('some.host', Resolv::DNS::Resource::IN::A).returns(Resolv::DNS::Resource::IN::A.new('127.13.0.2'))
    assert_equal '127.13.0.2', @record.get_resource_as_string!('some.host', Resolv::DNS::Resource::IN::A, :address)
  end

  def test_get_resource_as_string_with_sideeffects_raises_exception_when_resource_is_not_found
    Resolv::DNS.any_instance.expects(:getresource).with('some.host', Resolv::DNS::Resource::IN::A).raises(Resolv::ResolvError)
    assert_raises(Proxy::Dns::NotFound) { @record.get_resource_as_string!('some.host', Resolv::DNS::Resource::IN::A, :address) }
  end

  def test_get_resource_as_string
    Resolv::DNS.any_instance.expects(:getresource).with('some.host', Resolv::DNS::Resource::IN::A).returns(Resolv::DNS::Resource::IN::A.new('127.13.0.2'))
    assert_equal '127.13.0.2', @record.get_resource_as_string('some.host', Resolv::DNS::Resource::IN::A, :address)
  end

  def test_get_resource_as_string_wjen_resource_is_not_found
    Resolv::DNS.any_instance.expects(:getresource).with('some.host', Resolv::DNS::Resource::IN::A).raises(Resolv::ResolvError)
    assert_false @record.get_resource_as_string('some.host', Resolv::DNS::Resource::IN::A, :address)
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
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::A).returns([])
    assert_equal -1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_a_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::A).returns(ips('192.168.33.34', '192.168.33.33'))
    assert_equal 1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.11.11')
  end

  def test_a_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::A).returns(ips('192.168.33.33'))
    assert_equal 0, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_aaaa_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::AAAA).returns([])
    assert_equal -1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_aaaa_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:ABCD::1')
  end

  def test_aaaa_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_old_ptr_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getnames).with('192.168.33.33').returns([])
    assert_equal -1, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '192.168.33.33')
  end

  def test_old_ptr_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getnames).with('2001:db8:deef::1').returns(['some.host'])
    assert_equal 1, Proxy::Dns::Record.new.ptr_record_conflicts('another.host', '2001:db8:deef::1')
  end

  def test_old_ptr_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getnames).with('192.168.33.33').returns(['some.host'])
    assert_equal 0, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '192.168.33.33')
  end

  def test_ptr_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa',  Resolv::DNS::Resource::IN::PTR).returns([])
    assert_equal -1, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_ptr_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa',  Resolv::DNS::Resource::IN::PTR).returns([Resolv::DNS::Resource::IN::PTR.new('some.host')])
    assert_equal 1, Proxy::Dns::Record.new.ptr_record_conflicts('another.host', '33.33.168.192.in-addr.arpa')
  end

  def test_ptr_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa',  Resolv::DNS::Resource::IN::PTR).returns([Resolv::DNS::Resource::IN::PTR.new('some.host')])
    assert_equal 0, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_aaaa_record_conflicts_is_case_insensetive
    Resolv::DNS.any_instance.expects(:getresources).with('some.host',  Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:db8:deef::1')
  end

  def test_validate_ip
    assert_equal '192.168.33.33', Proxy::Dns::Record.new.to_ipaddress('192.168.33.33').to_s
    assert_equal '2001:db8:deef::1', Proxy::Dns::Record.new.to_ipaddress('2001:db8:deef::1').to_s
    assert_equal false, Proxy::Dns::Record.new.to_ipaddress('some.host')
  end

  def ips(*ips)
    ips.map {|ip| ip =~  Resolv::IPv4::Regex ? Resolv::DNS::Resource::IN::A.new(ip) : Resolv::DNS::Resource::IN::AAAA.new(ip) }
  end
end
