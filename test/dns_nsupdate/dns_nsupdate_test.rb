require 'test_helper'
require 'dns/dns'
require 'dns_nsupdate/dns_nsupdate_plugin'
require 'dns_nsupdate/dns_nsupdate_main'
require 'dns_nsupdate/dns_nsupdate_gss_main'

class DnsNsupdateTest < Test::Unit::TestCase
  def test_nsupdate_provider_initialization
    Proxy::Dns::Nsupdate::Plugin.load_test_settings(:dns_server => 'a_server')
    Proxy::Dns::Plugin.load_test_settings(:dns_ttl => 999)
    server = Proxy::Dns::Nsupdate::Record.new

    assert_equal "a_server", server.server
    assert_equal 999, server.ttl
  end

  def test_nsupdate_gss_provider_initialization
    Proxy::Dns::Plugin.load_test_settings(:dns_ttl => 999)
    Proxy::Dns::NsupdateGSS::Plugin.load_test_settings(:dns_server => 'a_server', :dns_tsig_principal => "test@test.com",
                                                       :dns_tsig_keytab => "keytab")
    server = Proxy::Dns::NsupdateGSS::Record.new

    assert_equal "a_server", server.server
    assert_equal 999, server.ttl
    assert_equal 'test@test.com', server.tsig_principal
    assert_equal 'keytab', server.tsig_keytab
  end

  def test_create_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add 192.168.33.33. 100 PTR some.host').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(false)

    Proxy::Dns::Nsupdate::Record.new(nil, 100).create_ptr_record('some.host', '192.168.33.33')
  end

  def test_overwrite_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns('some.host')

    Proxy::Dns::Nsupdate::Record.new(nil, 100).create_ptr_record('some.host', '192.168.33.33')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns('another.host')

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100).create_ptr_record('some.host', '192.168.33.33')
    end
  end

  def test_create_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update add some.host. 100 A 192.168.33.33').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns(false)

    Proxy::Dns::Nsupdate::Record.new(nil, 100).create_a_record('some.host', '192.168.33.33')
  end

  def test_overwrite_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns('192.168.33.33')

    Proxy::Dns::Nsupdate::Record.new(nil, 100).create_a_record('some.host', '192.168.33.33')
  end

  def test_create_duplicate_address_record_fails
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns('192.168.33.34')

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Nsupdate::Record.new(nil, 100).create_a_record('some.host', '192.168.33.33')
    end
  end

  def test_remove_ptr_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete 192.168.33.33 PTR').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(true)

    Proxy::Dns::Nsupdate::Record.new.remove_ptr_record('192.168.33.33')
  end

  def test_remove_address_record
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate).with('update delete some.host A').returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:nsupdate_disconnect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('some.host').returns(true)

    Proxy::Dns::Nsupdate::Record.new.remove_a_record('some.host')
  end

  def test_remove_address_record_raises_exception_if_host_does_not_exist
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('not_existing.example.com').returns(false)
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate_connect).returns(true)

    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Nsupdate::Record.new.remove_a_record('not_existing.example.com')
    end
  end

  def test_remove_ptr_record_raises_exception_if_host_does_not_exist
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate_connect).returns(true)
    Proxy::Dns::Nsupdate::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(false)

    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Nsupdate::Record.new.remove_ptr_record('192.168.33.33')
    end
  end

  def test_uses_dns_key_if_defined
    Proxy::Dns::Nsupdate::Plugin.load_test_settings(:dns_key => '/path/to/key')
    assert_equal "-k /path/to/key ", Proxy::Dns::Nsupdate::Record.new.nsupdate_args
  end
end
