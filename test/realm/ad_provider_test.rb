require 'test_helper'
require 'realm_ad/provider'

class RealmADTest < Test::Unit::TestCase
  def setup
    @realm = 'test_realm'
    @provider = Proxy::ADRealm::Provider.new(@realm, 'keytab_path', 'principal', 'domain-controller', 'ldap-user', 'ldap-password', 'ldap-port')
  end

  def test_find
    @provider.expects(:hostfqdn_hostname).with('a_host_fqdn').returns('a_host')
    @provider.expects(:ldap_host_exists?).with('a_host').returns('a_host')
    @provider.find('a_host_fqdn')
  end

  def test_find_if_host_does_not_exist
    @provider.expects(:hostfqdn_hostname).with('a_host_fqdn').returns('a_host')
    @provider.expects(:ldap_host_exists?).with('a_host').returns(nil)
    assert_nil @provider.find('a_host_fqdn')
  end

  def test_delete
    @provider.expects(:kinit_radcli_connect)
    @provider.expects(:radcli_delete)
    @provider.delete(@realm, 'a_host')
  end

  def test_delete_with_unrecognized_realm_raises_exception
    @provider.expects(:kinit_radcli_connect)
    assert_raises(Exception) { @provider.delete('unknown_realm', 'a_host') }
  end
end
