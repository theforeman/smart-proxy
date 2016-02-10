require 'test_helper'
require 'realm/activedirectory'

class RealmAd < Test::Unit::TestCase
  def test_realm_ad_provider_initialization
#    Proxy::Dns::Dnscmd::Plugin.load_test_settings(:dns_server => 'a_server')
#    Proxy::Dns::Plugin.load_test_settings(:dns_ttl => 999)
#    server = Proxy::Dns::Dnscmd::Record.new
#
#    assert_equal "a_server", server.server
#    assert_equal 999, server.ttl
  end

  def test_create_computer_account
    #Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns(false)
    #Proxy::Dns::Dnscmd::Record.any_instance.expects(:execute).with('/RecordAdd domain host.domain. A 192.168.33.33', anything).returns(true)
    #assert Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
  end

  def test_remove_computer_account
    #Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns('192.168.33.33')
    #Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
  end

  def test_create_duplicate_computer_account_raises_exception
    #Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns('192.168.33.34')

    #assert_raise Proxy::Dns::Collision do
     # Proxy::Dns::Dnscmd::Record.new.create_a_record('host.domain', '192.168.33.33')
    #end
  end

  def test_remove_non_existent_omputer_account_raises_exception
    #Proxy::Dns::Dnscmd::Record.any_instance.expects(:dns_find).with('host.domain').returns(false)
    #assert_raise Proxy::Dns::NotFound do
    #  Proxy::Dns::Dnscmd::Record.new.remove_a_record('host.domain')
    #end
  end
end
