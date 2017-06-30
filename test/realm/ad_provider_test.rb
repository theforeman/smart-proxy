require 'test_helper'
require 'realm_ad/provider'

class RealmADTest < Test::Unit::TestCase
  def setup
    @realm = 'test_realm'
    @provider = Proxy::ADRealm::Provider.new('test_realm', 'keytab_path', 'principal', 'domain-controller')
  end

  def test_create_host
    hostname = 'hostname'
    password = 'a_password'
    params = {}
    params[:rebuild] = "false"
    @provider.expects(:check_realm).with(@realm)
    @provider.expects(:kinit_radcli_connect)
    @provider.expects(:generate_password).returns(password)
    @provider.expects(:radcli_join)
    @provider.create(@realm, hostname, params)
  end

  def test_create_with_unrecognized_realm_raises_exception
    assert_raises(Exception) { @provider.create('unknown_realm', 'a_host', {})}
  end

  def test_create_rebuild
    hostname = 'hostname'
    password = 'a_password'
    params = {}
    params[:rebuild] = "true"
    @provider.expects(:check_realm).with(@realm)
    @provider.expects(:kinit_radcli_connect)
    @provider.expects(:generate_password).returns(password)
    @provider.expects(:radcli_password)
    @provider.create(@realm, hostname, params)
  end

  def test_rebuild_with_unrecognized_realm_raises_exception
    params = {}
    params[:rebuild] = "true"
    assert_raises(Exception) { @provider.create('unknown_realm', 'a_host', params) }
  end

  def test_find
    assert_true @provider.find('a_host_fqdn')
  end

  def test_delete 
    @provider.expects(:check_realm).with(@realm)
    @provider.expects(:kinit_radcli_connect)
    @provider.expects(:radcli_delete)
    @provider.delete(@realm, 'a_host')
  end
 
  def test_delete_unrecognized_realm_raises_exception
    @provider.expects(:kinit_radcli_connect)
    assert_raises(Exception) { @provider.delete('unkown_realm', 'a_host') }
  end
end
