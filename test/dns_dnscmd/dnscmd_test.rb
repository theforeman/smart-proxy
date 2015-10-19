require 'test_helper'
require 'dns_dnscmd/dns_dnscmd'
require 'dns_dnscmd/dns_dnscmd_main'

class DnsCmdTest < Test::Unit::TestCase
  def test_dnscmd_provider_initialization
    Proxy::Dns::Dnscmd::Plugin.load_test_settings(:dns_server => 'a_server')
    Proxy::Dns::Plugin.load_test_settings(:dns_ttl => 999)
    server = Proxy::Dns::Dnscmd::Record.new

    assert_equal "a_server", server.server
    assert_equal 999, server.ttl
  end

  def test_create_address_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns(false)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd domain host.domain. A 192.168.33.33', anything).returns(true)
    assert Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
  end

  def test_overwrite_address_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns('192.168.33.33')
    Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
  end

  def test_create_duplicate_address_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns('192.168.33.34')

    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
    end
  end

  def test_create_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(false)
    assert Proxy::Dns::Dnscmd::Record.new.create_ptr_record('host.domain', '192.168.33.33')
  end

  def test_overwrite_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns('host.domain')
    Proxy::Dns::Dnscmd::Record.new.create_ptr_record('host.domain', '192.168.33.33')
  end

  def test_create_duplicate_ptr_record_fails
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns('another.host.domain')
    assert_raise Proxy::Dns::Collision do
      Proxy::Dns::Dnscmd::Record.new.create_ptr_record('host.domain', '192.168.33.33')
    end
  end

  def test_remove_address_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns(true)
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordDelete domain host.domain. A /f', anything).returns(true)
    assert Proxy::Dns::Dnscmd::Record.new.remove_a_record('host.domain')
  end

  def test_remove_non_existent_address_record_raises_exception
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns(false)
    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Dnscmd::Record.new.remove_a_record('host.domain')
    end
  end

  def test_remove_ptr_record
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(true)
    assert Proxy::Dns::Dnscmd::Record.new.remove_ptr_record('192.168.33.33')
  end

  def test_remove_nonexistent_ptr_record_raises_exception
    Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('192.168.33.33').returns(false)
    assert_raise Proxy::Dns::NotFound do
      Proxy::Dns::Dnscmd::Record.new.remove_ptr_record('192.168.33.33')
    end
  end
end
