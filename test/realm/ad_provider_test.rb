require 'test_helper'
require 'realm_ad/provider'

class RealmADTest < Test::Unit::TestCase
  def setup
    @provider = Proxy::ADRealm::Provider.new('realm', 'keytab', 'principal', 'domain-controller', 'ldap-user', 'ldap-password')
  end

  def test_find
    # private ldap_find returns a hostname 'a_host'
    @provider.find('a_host')
  end

  def test_find_if_host_does_not_exist
    # private ldap_find throws exception with message 'not found'
    assert_nil @provider.find('a_host')
  end
 
  def test_delete
    # private radcli_delete with 'a_host' return json with hostname
  end

  def test_delete_with_unrecognized_realm_raises_exception
    # raises exception, @provider.delete('unkown_realm', 'a_host')
  end

  def test_create_host
  end

  def test_create_host_unrecognized_realm_raises_exception
  end

  def test_create_raises_exception_on_error
  end
end
