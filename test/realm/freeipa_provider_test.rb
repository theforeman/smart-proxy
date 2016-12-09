# -*- coding: utf-8 -*-
require 'test_helper'
require 'xmlrpc/client'
require 'realm_freeipa/provider'

class FreeIPATest < Test::Unit::TestCase
  class IpaConfigParserForTesting
    attr_reader :realm

    def initialize(uri, realm)
      @uri = uri
      @realm = realm
    end

    def uri
      @uri.to_s
    end

    def host
      @uri.host
    end

    def scheme
      @uri.scheme
    end
  end

  def setup
    @realm = 'test_realm'
    @ipa_config = IpaConfigParserForTesting.new('https://localhost', @realm)
    @provider = Proxy::FreeIPARealm::Provider.new(@ipa_config, 'keytab', 'prinicipal', true)
  end

  def test_find
    @provider.expects(:ipa_call).with('host_show', ['a_host'])
    @provider.find('a_host')
  end

  def test_find_if_host_does_not_exist
    @provider.expects(:ipa_call).raises(XMLRPC::FaultException.new(1, 'not found'))
    assert_nil @provider.find('a_host')
  end

  def test_find_if_with_exception
    @provider.expects(:ipa_call).raises(XMLRPC::FaultException.new(1, ''))
    assert_raises(XMLRPC::FaultException) { @provider.find('a_host') }
  end

  def test_delete
    ok_result = {:a => 'a'}
    @provider.expects(:ipa_call).with('host_del', ['a_host'], 'updatedns' => true).returns(ok_result)
    assert_equal JSON.pretty_generate(ok_result), @provider.delete(@realm, 'a_host')
  end

  def test_delete_with_unrecognized_realm_raises_exception
    assert_raises(Exception) { @provider.delete('unknown_realm', 'a_host')}
  end

  def test_delete_respects_remove_dns_parameter
    provider = Proxy::FreeIPARealm::Provider.new(@ipa_config, 'keytab', 'prinicipal', false)
    provider.expects(:ipa_call).with('host_del', ['a_host'], 'updatedns' => false).returns(true)
    provider.delete(@realm, 'a_host')
  end

  def test_delete_if_host_does_not_exist_and_remove_dns_is_true
    @provider.expects(:ipa_call).with('host_del', ['a_host'], 'updatedns' => true).raises(StandardError)
    @provider.expects(:ipa_call).with('host_del', ['a_host'], 'updatedns' => false).returns(true)
    @provider.delete(@realm, 'a_host')
  end

  def test_rebuild_host
    hostname = 'hostname'
    setattr = 'userclass'
    @provider.expects(:find).with(hostname).returns('result' => {'has_keytab' => true})
    @provider.expects(:ipa_call).with('host_disable', [hostname])
    @provider.expects(:ipa_call).with('host_mod', [hostname], :random => 1, :setattr => ['userclass=userclass']).returns({})
    @provider.create(@realm, hostname, :rebuild => 'true', setattr => setattr)
  end

  def test_modify_host
    hostname = 'hostname'
    setattr = 'userclass'
    @provider.expects(:find).with(hostname).returns('result' => {})
    @provider.expects(:ipa_call).with('host_mod', [hostname], :setattr => ['userclass=userclass']).returns({})
    @provider.create(@realm, hostname, setattr => setattr)
  end

  def test_create_host
    hostname = 'hostname'
    setattr = 'userclass'
    @provider.expects(:find).with(hostname).returns(nil)
    @provider.expects(:ipa_call).with('host_add', [hostname], :random => 1, :force => 1, :setattr => ['userclass=userclass']).returns({})
    @provider.create(@realm, hostname, setattr => setattr)
  end

  def test_create_with_unrecognized_realm_raises_exception
    assert_raises(Exception) { @provider.create('unknown_realm', 'a_host', {})}
  end

  def test_modify_reports_lack_of_changes
    @provider.expects(:find).returns('result' => {})
    @provider.expects(:ipa_call).raises(RuntimeError.new('no modifications'))
    assert_equal({'message' => 'nothing to do'}, JSON.parse(@provider.create(@realm, 'hostname', {})))
  end

  def test_create_raises_exception_on_error
    @provider.expects(:find).returns('result' => {})
    @provider.expects(:ipa_call).raises(RuntimeError.new('blah'))
    assert_raises(RuntimeError) { @provider.create(@realm, 'hostname', {}) }
  end

  def test_ensure_utf
    return if RUBY_VERSION =~ /^1\.8/
    unicode_string = 'žluťoučký'
    malformed_string = unicode_string.dup.force_encoding('ASCII-8BIT')
    malformed_hash = { malformed_string => { malformed_string => [malformed_string, 'test'],
                                             'hello' => 'world' },
                       1 => malformed_string,
                       :key => malformed_string }
    new_hash = Proxy::FreeIPARealm::Provider.ensure_utf(malformed_hash)
    assert_equal({ unicode_string => { unicode_string => [ unicode_string, 'test'],
                                       'hello' => 'world' },
                   1 => unicode_string,
                   :key => unicode_string }, new_hash)

    deserialized_hash = JSON.load(JSON.pretty_generate(new_hash))
    assert_equal({ unicode_string => { unicode_string => [ unicode_string, 'test'],
                                       'hello' => 'world' },
                   '1' => unicode_string,
                   'key' => unicode_string }, deserialized_hash)
  end
end
