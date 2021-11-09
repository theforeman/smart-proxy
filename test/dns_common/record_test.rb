require 'test_helper'
require 'dns_common/dns_common'

class DnsRecordTest < Test::Unit::TestCase
  def setup
    @record = Proxy::Dns::Record.new
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
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::A).returns([])
    assert_equal -1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_a_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::A).returns(ips('192.168.33.34', '192.168.33.33'))
    assert_equal 1, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.11.11')
  end

  def test_a_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::A).returns(ips('192.168.33.33'))
    assert_equal 0, Proxy::Dns::Record.new.a_record_conflicts('some.host', '192.168.33.33')
  end

  def test_aaaa_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::AAAA).returns([])
    assert_equal -1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_aaaa_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 1, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:ABCD::1')
  end

  def test_aaaa_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:DB8:DEEF::1')
  end

  def test_ptr_record_conflicts_no_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa', Resolv::DNS::Resource::IN::PTR).returns([])
    assert_equal -1, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_ptr_record_conflicts_has_conflict
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa', Resolv::DNS::Resource::IN::PTR).returns([Resolv::DNS::Resource::IN::PTR.new('some.host')])
    assert_equal 1, Proxy::Dns::Record.new.ptr_record_conflicts('another.host', '33.33.168.192.in-addr.arpa')
  end

  def test_ptr_record_conflicts_but_nothing_todo
    Resolv::DNS.any_instance.expects(:getresources).with('33.33.168.192.in-addr.arpa', Resolv::DNS::Resource::IN::PTR).returns([Resolv::DNS::Resource::IN::PTR.new('some.host')])
    assert_equal 0, Proxy::Dns::Record.new.ptr_record_conflicts('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_aaaa_record_conflicts_is_case_insensetive
    Resolv::DNS.any_instance.expects(:getresources).with('some.host', Resolv::DNS::Resource::IN::AAAA).returns(ips('2001:DB8:DEEF::1'))
    assert_equal 0, Proxy::Dns::Record.new.aaaa_record_conflicts('some.host', '2001:db8:deef::1')
  end

  def test_create_srv_record
    Proxy::Dns::Record.any_instance.expects(:do_create).with('_sip._tcp.example.com.', '10 60 5060 bigbox.example.com.', 'SRV')

    assert_nil Proxy::Dns::Record.new.create_srv_record('_sip._tcp.example.com.', '10 60 5060 bigbox.example.com.')
  end

  def test_create_a_record
    Proxy::Dns::Record.any_instance.expects(:a_record_conflicts).returns(-1)
    Proxy::Dns::Record.any_instance.expects(:do_create).with('some.host', '192.168.33.22', 'A')

    assert_nil Proxy::Dns::Record.new.create_a_record('some.host', '192.168.33.22')
  end

  def test_overwrite_a_record
    Proxy::Dns::Record.any_instance.expects(:a_record_conflicts).returns(0)

    assert_nil Proxy::Dns::Record.new.create_a_record('some.host', '192.168.33.22')
  end

  def test_create_duplicate_a_record_fails
    Proxy::Dns::Record.any_instance.expects(:a_record_conflicts).returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Record.new.create_a_record('some.host', '2001:db8::1')
    end
  end

  def test_create_aaaa_record
    Proxy::Dns::Record.any_instance.expects(:aaaa_record_conflicts).returns(-1)
    Proxy::Dns::Record.any_instance.expects(:do_create).with('some.host', '2001:db8::1', 'AAAA')

    assert_nil Proxy::Dns::Record.new.create_aaaa_record('some.host', '2001:db8::1')
  end

  def test_overwrite_aaaa_record
    Proxy::Dns::Record.any_instance.expects(:aaaa_record_conflicts).returns(0)

    assert_nil Proxy::Dns::Record.new.create_aaaa_record('some.host', '2001:db8::1')
  end

  def test_create_duplicate_aaaa_record_fails
    Proxy::Dns::Record.any_instance.expects(:aaaa_record_conflicts).returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Record.new.create_aaaa_record('some.host', '2001:db8::1')
    end
  end

  def test_create_cname_record
    Proxy::Dns::Record.any_instance.expects(:cname_record_conflicts).returns(-1)
    Proxy::Dns::Record.any_instance.expects(:do_create).with('some.host', 'target.example.com', 'CNAME')

    assert_nil Proxy::Dns::Record.new.create_cname_record('some.host', 'target.example.com')
  end

  def test_overwrite_cname_record
    Proxy::Dns::Record.any_instance.expects(:cname_record_conflicts).returns(0)

    assert_nil Proxy::Dns::Record.new.create_cname_record('some.host', 'target.example.com')
  end

  def test_create_duplicate_cname_record_fails
    Proxy::Dns::Record.any_instance.expects(:cname_record_conflicts).returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Record.new.create_cname_record('some.host', 'target.example.com')
    end
  end

  def test_create_ptr_record
    Proxy::Dns::Record.any_instance.expects(:ptr_record_conflicts).returns(-1)
    Proxy::Dns::Record.any_instance.expects(:do_create).with('22.33.168.192.in-addr.arpa', 'some.host', 'PTR')

    assert_nil Proxy::Dns::Record.new.create_ptr_record('some.host', '22.33.168.192.in-addr.arpa')
  end

  def test_overwrite_ptr_record
    Proxy::Dns::Record.any_instance.expects(:ptr_record_conflicts).returns(0)

    assert_nil Proxy::Dns::Record.new.create_ptr_record('some.host', '22.33.168.192.in-addr.arpa')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Record.any_instance.expects(:ptr_record_conflicts).returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Record.new.create_ptr_record('some.host', '22.33.168.192.in-addr.arpa')
    end
  end

  def test_remove_a_record
    Proxy::Dns::Record.any_instance.expects(:do_remove).with('some.host', 'A')

    assert_nil Proxy::Dns::Record.new.remove_a_record('some.host')
  end

  def test_remove_aaaa_record
    Proxy::Dns::Record.any_instance.expects(:do_remove).with('some.host', 'AAAA')

    assert_nil Proxy::Dns::Record.new.remove_aaaa_record('some.host')
  end

  def test_remove_cname_record
    Proxy::Dns::Record.any_instance.expects(:do_remove).with('some.host', 'CNAME')

    assert_nil Proxy::Dns::Record.new.remove_cname_record('some.host')
  end

  def test_remove_ptr_record
    Proxy::Dns::Record.any_instance.expects(:do_remove).with('22.33.168.192.in-addr.arpa', 'PTR')

    assert_nil Proxy::Dns::Record.new.remove_ptr_record('22.33.168.192.in-addr.arpa')
  end

  def ips(*ips)
    ips.map { |ip| (ip =~ Resolv::IPv4::Regex) ? Resolv::DNS::Resource::IN::A.new(ip) : Resolv::DNS::Resource::IN::AAAA.new(ip) }
  end
end
