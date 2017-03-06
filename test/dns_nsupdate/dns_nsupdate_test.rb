require 'test_helper'
require 'dns_common/dns_common'
require 'dns_nsupdate/nsupdate_configuration'
require 'dns_nsupdate/dns_nsupdate_plugin'
require 'dns_nsupdate/dns_nsupdate_main'

class DnsNsupdateTest < Test::Unit::TestCase
  def test_do_create_ptr
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add 33.33.168.192.in-addr.arpa. 100 PTR some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil).do_create('33.33.168.192.in-addr.arpa', 'some.host', 'PTR')
  end

  def test_create_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add some.host. 100 A 192.168.33.33').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil).do_create('some.host', '192.168.33.33', 'A')
  end

  def test_create_aaaa_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add some.host. 100 AAAA 2001:db8::1').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil).do_create('some.host', '2001:db8::1', 'AAAA')
  end

  def test_create_cname_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add alias.host. 100 CNAME some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil).do_create('alias.host', 'some.host', 'CNAME')
  end

  def test_remove_ptr_v4_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 33.33.168.192.in-addr.arpa PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil).do_remove('33.33.168.192.in-addr.arpa', 'PTR')
  end

  def test_remove_ptr_v6_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil).do_remove('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa', 'PTR')
  end

  def test_remove_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete some.host A').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil).do_remove('some.host', 'A')
  end

  def test_remove_aaaa_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete some.host AAAA').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil).do_remove('some.host', 'AAAA')
  end

  def test_remove_cname_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete alias.host CNAME').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_close)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil).do_remove('alias.host', 'CNAME')
  end

  def test_uses_dns_key_if_defined
    assert_equal "-k /path/to/key ", Proxy::Dns::Nsupdate::Record.new('a_server', 999, '/path/to/key').nsupdate_args
  end

  def test_omits_dns_key_when_empty
    assert_equal "", Proxy::Dns::Nsupdate::Record.new('a_server', 999, '').nsupdate_args
  end
end
