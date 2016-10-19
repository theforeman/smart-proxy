require 'test_helper'
require 'dns_dnscmd/dns_dnscmd'
require 'dns_dnscmd/dns_dnscmd_main'

class DnscmdForTesting < Proxy::Dns::Dnscmd::Record
  def initialize(dns_zones, rewrite_map = nil)
    @enum_zones = dns_zones
    super('a_server', 999, rewrite_map)
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
    @rewrite_server = DnscmdForTesting.new(["33.168.192.in-addr.example.com"], {'arpa$' => 'example.com'})
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

  def test_create_rewritten_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(-1)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd 33.168.192.in-addr.example.com 33.33.168.192.in-addr.example.com. PTR host.foo.bar.domain.local.', anything).returns(true)
    assert_nil @rewrite_server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
  end

  def test_overwrite_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(0)
    assert_nil @server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
  end

  def test_overwrite_rewritten_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(0)
    assert_nil @rewrite_server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(1)
    assert_raise Proxy::Dns::Collision do
      @server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
    end
  end

  def test_create_duplicate_rewritten_ptr_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:ptr_record_conflicts).with('host.foo.bar.domain.local', '192.168.33.33').returns(1)
    assert_raise Proxy::Dns::Collision do
      @rewrite_server.create_ptr_record('host.foo.bar.domain.local', '33.33.168.192.in-addr.arpa')
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

  def test_remove_address_records_with_longest_zone_match
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:enum_records).with('bar.domain.local', 'host.foo.bar.domain.local',  'A').returns(['1.1.1.1','2.2.2.2'])
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_specific_record_from_zone).with('bar.domain.local', 'host.foo.bar.domain.local', '1.1.1.1', 'A').returns(true)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_specific_record_from_zone).with('bar.domain.local', 'host.foo.bar.domain.local', '2.2.2.2', 'A').returns(true)
    assert_nil @server.remove_a_record('host.foo.bar.domain.local')
  end

  def test_remove_a_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_record).with('host.example.com','A').returns(nil)
    assert_nil @server.remove_a_record('host.example.com')
  end

  def test_remove_aaaa_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_record).with('host.example.com','AAAA').returns(nil)
    assert_nil @server.remove_aaaa_record('host.example.com')
  end

  def test_remove_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_record).with('33.33.168.192.in-addr.arpa','PTR').returns(nil)
    assert_nil @server.remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_rewritten_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_record).with('33.33.168.192.in-addr.example.com','PTR').returns(nil)
    assert_nil @rewrite_server.remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_cname_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_record).with('alias.example.com','CNAME').returns(nil)
    assert_nil @server.remove_cname_record('alias.example.com')
  end

  def test_remove_ptr_records
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:enum_records).with('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa',  'PTR').returns(['host.domain.local'])
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_specific_record_from_zone).with('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa', 'host.domain.local', 'PTR').returns(true)
    assert_nil @server.remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_rewritten_ptr_records
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:enum_records).with('33.168.192.in-addr.example.com', '33.33.168.192.in-addr.example.com',  'PTR').returns(['host.domain.local'])
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_specific_record_from_zone).with('33.168.192.in-addr.example.com', '33.33.168.192.in-addr.example.com', 'host.domain.local', 'PTR').returns(true)
    assert_nil @rewrite_server.remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_specific_a_record_from_zone
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete domain.local host.domain.local. A 192.168.33.33 /f', anything).returns(true)
    assert_nil @server.remove_specific_record_from_zone('domain.local', 'host.domain.local', '192.168.33.33', 'A')
  end

  def test_remove_specific_ptr_record_from_zone
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. PTR host.domain.local /f', anything).returns(true)
    assert_nil @server.remove_specific_record_from_zone('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa', 'host.domain.local', 'PTR')
  end

  def test_remove_cname_records
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:enum_records).with('bar.domain.local', 'alias.foo.bar.domain.local',  'CNAME').returns(['host.domain.local'])
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:remove_specific_record_from_zone).with('bar.domain.local', 'alias.foo.bar.domain.local', 'host.domain.local', 'CNAME').returns(true)
    assert_nil @server.remove_cname_record('alias.foo.bar.domain.local')
  end

  def test_dns_zone_matches_second_best_match_if_zone_name_equals_host_name
    assert_equal('domain.local', @server.match_zone('bar.domain.local', @server.enum_zones))
  end

  def test_dns_zone_matches_sole_available_zone
    assert_equal('sole.domain', Proxy::Dns::Dnscmd::Record.new('server', 999, nil).match_zone('host.foo.bar.sole.domain', ["sole.domain"]))
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
      "TrustAnchors"
    ], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_zones
  end

  def test_enum_a_records
    to_parse = '
Returned records:
@ 3600 A	192.168.33.33
		 3600 A 192.168.33.34

Command completed successfully.


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords domain.local host.domain.local. /Type A', 'EnumRecords', true).returns(to_parse)
    assert_equal ['192.168.33.33','192.168.33.34'], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('domain.local', 'host.domain.local', 'A')
  end

  def test_enum_aaaa_records
    to_parse = '
Returned records:
@ 3600 AAAA	2001:db8:85a3::8a2e:370:7335
		 3600 AAAA	2001:db8:85a3::8a2e:370:7334

Command completed successfully.


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords domain.local host.domain.local. /Type AAAA', 'EnumRecords', true).returns(to_parse)
    assert_equal ['2001:db8:85a3::8a2e:370:7335','2001:db8:85a3::8a2e:370:7334'], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('domain.local', 'host.domain.local', 'AAAA')
  end

  def test_enum_cname_records
    to_parse = '
Returned records:
@ 3600 CNAME	alias.example.com.

Command completed successfully.


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords example.com alias.example.com. /Type CNAME', 'EnumRecords', true).returns(to_parse)
    assert_equal ['alias.example.com.'], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('example.com', 'alias.example.com', 'CNAME')
  end

  def test_enum_ptr_records
    to_parse = '
Returned records:
@ 3600 PTR	host.domain.local.

Command completed successfully.


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. /Type PTR', 'EnumRecords', true).returns(to_parse)
    assert_equal ['host.domain.local.'], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa', 'PTR')
  end

  def test_enum_ptr_records_when_multiple
    to_parse = '
Returned records:
@ 3600 PTR	host.domain.local.
		 3600 PTR	host2.domain.local.

Command completed successfully.


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. /Type PTR', 'EnumRecords', true).returns(to_parse)
    assert_equal ['host.domain.local.','host2.domain.local.'], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa', 'PTR')
  end

  def test_enum_ptr_records_when_none
    to_parse = '
DNS Server failed to enumerate records for node 33.33.168.192.in-addr.arpa..
    Status = 9714 (0x000025f2)
Command failed:  DNS_ERROR_NAME_DOES_NOT_EXIST     9714    0x25F2


'.split("\n")
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/EnumRecords 33.168.192.in-addr.arpa 33.33.168.192.in-addr.arpa. /Type PTR', 'EnumRecords', true).returns(to_parse)
    assert_equal [], Proxy::Dns::Dnscmd::Record.new('server', 999, nil).enum_records('33.168.192.in-addr.arpa', '33.33.168.192.in-addr.arpa', 'PTR')
  end
end
