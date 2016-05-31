require 'test_helper'
require 'dns_dnscmd/dns_dnscmd'
require 'dns_dnscmd/dns_dnscmd_main'

class DnscmdForTesting < Proxy::Dns::Dnscmd::Record
  def initialize(dns_zones)
    @enum_zones = dns_zones
  end
  attr_accessor :enum_zones
end

class DnsCmdTest < Test::Unit::TestCase
  def setup
    @server = DnscmdForTesting.new(["_msdcs.bar.domain.local",
                                    "168.192.in-addr.arpa",
                                    "33.168.192.in-addr.arpa",
                                    "f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa",
                                    "bar.domain.local",
                                    "domain.local",
                                    "TrustAnchors"])
  end

  def test_dnscmd_provider_initialization
    Proxy::Dns::Dnscmd::Plugin.load_test_settings(:dns_server => 'a_server')
    Proxy::Dns::Plugin.load_test_settings(:dns_ttl => 999)
    server = Proxy::Dns::Dnscmd::Record.new

    assert_equal "a_server", server.server
    assert_equal 999, server.ttl
  end

  def test_create_a_record_with_longest_zone_match
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:a_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(-1)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd bar.domain.local host.foo.bar.domain.local. A 192.168.33.33', anything).returns(true)
    assert_nil @server.create_a_record('host.foo.bar.domain.local', '192.168.33.33')
  end

  def test_create_aaaa_record_with_longest_zone_match
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:aaaa_record_conflicts).with('host.foo.bar.domain.local', '2001:db8:deef::1').returns(-1)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd bar.domain.local host.foo.bar.domain.local. AAAA 2001:db8:deef::1', anything).returns(true)
    assert_nil @server.create_aaaa_record('host.foo.bar.domain.local', '2001:db8:deef::1')
  end

  def test_overwrite_address_record_with_longest_zone_match
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:a_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(0)
    assert_nil @server.create_a_record('host.foo.bar.domain.local', '192.168.33.33')
  end

  def test_create_duplicate_address_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:a_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(1)
    assert_raise Proxy::Dns::Collision do
      @server.create_a_record('host.foo.bar.domain.local', '192.168.33.33')
    end
  end

  def test_create_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(-1)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. PTR host.foo.bar.domain.local.', anything).returns(true)
    assert_nil @server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
  end

  def test_overwrite_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(0)
    assert_nil @server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(1)
    assert_raise Proxy::Dns::Collision do
      @server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
    end
  end

  def test_create_cname_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:cname_record_conflicts).with('alias.foo.bar.domain.local', 'host.foo.bar.domain.local').returns(-1)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd bar.domain.local alias.foo.bar.domain.local. CNAME host.foo.bar.domain.local', anything).returns(true)
    assert_nil @server.create_cname_record('alias.foo.bar.domain.local', 'host.foo.bar.domain.local')
  end

  def test_overwrite_cname_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:cname_record_conflicts).with('alias.foo.bar.domain.local', 'host.foo.bar.domain.local').returns(0)
    assert_nil @server.create_cname_record('alias.foo.bar.domain.local', 'host.foo.bar.domain.local')
  end

  def test_create_duplicate_cname_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:cname_record_conflicts).with('alias.foo.bar.domain.local', 'host.foo.bar.domain.local').returns(1)
    assert_raise Proxy::Dns::Collision do
      @server.create_cname_record('alias.foo.bar.domain.local', 'host.foo.bar.domain.local')
    end
  end

  def test_remove_address_record_with_longest_zone_match
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete bar.domain.local host.foo.bar.domain.local. A /f', anything).returns(true)
    assert_nil @server.remove_a_record('host.foo.bar.domain.local')
  end

  def test_remove_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. PTR /f', anything).returns(true)
    assert_nil @server.remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_cname_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete bar.domain.local alias.foo.bar.domain.local. CNAME /f', anything).returns(true)
    assert_nil @server.remove_cname_record('alias.foo.bar.domain.local')
  end

  def test_dns_zone_matches_second_best_match_if_zone_name_equals_host_name
    assert_equal('domain.local', @server.match_zone('bar.domain.local', @server.enum_zones))
  end

  def test_dns_zone_matches_sole_available_zone
    assert_equal('sole.domain', Proxy::Dns::Dnscmd::Record.new.match_zone('host.foo.bar.sole.domain', ["sole.domain"]))
  end

  def test_dns_non_authoritative_zone_raises_exception
    assert_raise Proxy::Dns::NotFound do
      @server.match_zone('host.foo.bar.domain.com', ['domain.local'])
    end
    assert_raise Proxy::Dns::NotFound do
      @server.match_zone('33.33.16.192.in-addr.arpa', ['168.192.in-addr.arpa'])
    end
    assert_raise Proxy::Dns::NotFound do
      @server.match_zone('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.e.e.d.8.b.d.1.1.0.0.2.ip6.arpa', ['f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa'])
    end
  end

  def test_dnscmd_enum_zones_parses_primary_zones_only
    to_parse = '
Enumerated zone list:
        Zone count = 8

 Zone name                      Type       Storage         Properties

 .                              Cache      AD-Domain
 _msdcs.bar.domain.local        Primary    AD-Forest       Secure
 168.192.in-addr.arpa           Primary    AD-Domain       Rev
 33.168.192.in-addr.arpa        Primary    AD-Domain       Secure Rev Aging
 f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa  Primary    AD-Domain       Secure Rev
 bar.domain.local               Primary    AD-Domain       Secure Aging
 domain.local                   Primary    AD-Domain       Secure
 domain.com                     Secondary    File
 TrustAnchors                   Primary    AD-Forest


Command completed successfully.'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumZones', nil, true).returns(to_parse)
    assert_equal [
      "_msdcs.bar.domain.local",
      "168.192.in-addr.arpa",
      "33.168.192.in-addr.arpa",
      "f.e.e.d.8.b.d.0.1.0.0.2.ip6.arpa",
      "bar.domain.local",
      "domain.local",
      "TrustAnchors"], Proxy::Dns::Dnscmd::Record.new.enum_zones
  end
end
