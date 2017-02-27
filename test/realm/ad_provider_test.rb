require 'test_helper'
require 'realm_ad/provider'

class RealmADTest < Test::Unit::TestCase
  def setup
    @realm = 'test_realm'
    @provider = Proxy::ADRealm::Provider.new(@realm, 'keytab_path', 'principal', 'domain-controller', 'ldap-user', 'ldap-password', 'ldap-port')
  end

  # New host. hostname is set, rebuild is null. radcli_join doesnt raise exception.
  # create method returns json of otp. otp function returns _i7@PhgpAnjn.

  # New host. hostname is set. rebuild is not specified. radcli_join raises an exception.
  # create method doesnt return json, propagates exception back to caller that return error 400.

  # Rebuild host. hostname is not null. rebuild is set. radcli_reset doesnt raise exception.
  # create method return json of otp. otp function returns Nx7$Av12Aja_ string.

  # Rebuild host. hostname is set. rebuild is set. radcli_reset raises an exception.
  # create method doesnt return json, propagates exception back to caller that return error 400.

  # Rebuild host. host account doesnt exist. radcli_join throws an "not found" exception. Returns 404 if not found.
  # Rebuild host, reset password. radcli_password throws an "Not found" exception". Return 404 if not found.

  # Delete host. hostname is not null. radcli_delete doesnt raise exception. delete returns nothing.
  # Delete host. radcli_delete raises an exception. delete returns nothing.
  # Delete host. radcli_delete throws "not found" exception.  delete returns 404 error.

  def test_delete
    ok_result = {:a => 'a'}
    @provider.expects()
  end
end
