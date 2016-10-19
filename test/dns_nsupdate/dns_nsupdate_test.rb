require 'test_helper'
require 'dns/dns'
require 'dns_nsupdate/dns_nsupdate_plugin'
require 'dns_nsupdate/dns_nsupdate_main'
require 'dns_nsupdate/dns_nsupdate_gss_main'

class DnsNsupdateTest < Test::Unit::TestCase
  def test_create_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add 33.33.168.192.in-addr.arpa. 100 PTR some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(-1)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_create_rewritten_ptr_record_a
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add 33.33.168.192.in-addr.example.com. 100 PTR some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(-1)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, {"arpa$" => "example.com" }, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_create_rewritten_ptr_record_b
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add 33.0/26.33.168.192.in-addr.arpa. 100 PTR some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(-1)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, {'33\.168\.192\.in-addr\.arpa$' => '0/26.\0' }, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
  end


  def test_overwrite_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(0)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_overwrite_rewritten_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(0)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, {'33\.168\.192\.in-addr\.arpa$' => '0/26.\0' }, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
    end
  end

  def test_create_duplicate_rewritten_ptr_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:ptr_record_conflicts).with('some.host', '192.168.33.33').returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100, {'33\.168\.192\.in-addr\.arpa$' => '0/26.\0' }, nil).create_ptr_record('some.host', '33.33.168.192.in-addr.arpa')
    end
  end

  def test_create_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add some.host. 100 A 192.168.33.33').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:a_record_conflicts).with('some.host', '192.168.33.33').returns(-1)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_a_record('some.host', '192.168.33.33')
  end

  def test_overwrite_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:a_record_conflicts).with('some.host', '192.168.33.33').returns(0)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_a_record('some.host', '192.168.33.33')
  end

  def test_create_duplicate_address_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:a_record_conflicts).with('some.host', '192.168.33.33').returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_a_record('some.host', '192.168.33.33')
    end
  end

  def test_remove_cname_record_fails
    assert_raise Proxy::Dns::Error do
      Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).remove_cname_record('some.host')
    end
  end

  def test_create_aaaa_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add some.host. 100 AAAA 2001:db8::1').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:aaaa_record_conflicts).with('some.host', '2001:db8::1').returns(-1)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_aaaa_record('some.host', '2001:db8::1')
  end

  def test_overwrite_aaaa_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:aaaa_record_conflicts).with('some.host', '2001:db8::1').returns(0)

    assert_nil Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_aaaa_record('some.host', '2001:db8::1')
  end

  def test_create_duplicate_aaaa_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:aaaa_record_conflicts).with('some.host', '2001:db8::1').returns(1)

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100, nil, nil).create_aaaa_record('some.host', '2001:db8::1')
    end
  end

  def test_remove_ptr_v4_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 33.33.168.192.in-addr.arpa PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('33.33.168.192.in-addr.arpa').returns(true)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_ptr_record('33.33.168.192.in-addr.arpa')
  end
  
  def test_remove_rewritten_ptr_v4_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 33.33.168.192.in-addr.example.com PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('33.33.168.192.in-addr.arpa').returns(true)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, {"arpa$" => "example.com" }, nil).remove_ptr_record('33.33.168.192.in-addr.arpa')
  end

  def test_remove_ptr_v6_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa').returns(true)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_ptr_record('1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa')
  end

  def test_remove_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete some.host A').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns(true)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_a_record('some.host')
  end

  def test_remove_address_record_raises_exception_if_host_does_not_exist
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('not_existing.example.com').returns(false)
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate_connect).returns(true)

    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_a_record('not_existing.example.com')
    end
  end

  def test_remove_aaaa_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete some.host AAAA').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns(true)

    assert_nil Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_aaaa_record('some.host')
  end

  def test_remove_aaaa_record_raises_exception_if_host_does_not_exist
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('not_existing.example.com').returns(false)
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate_connect).returns(true)

    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_aaaa_record('not_existing.example.com')
    end
  end

  def test_remove_ptr_record_raises_exception_if_host_does_not_exist
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('33.33.168.192.in-addr.arpa').returns(false)

    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, nil).remove_ptr_record('33.33.168.192.in-addr.arpa')
    end
  end

  def test_uses_dns_key_if_defined
    assert_equal "-k /path/to/key ", Proxy::Dns::Nsupdate::Record.new('a_server', 999, nil, '/path/to/key').nsupdate_args
  end
end
