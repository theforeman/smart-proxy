require 'test_helper'
require 'realm_ad/provider'

class RealmADTest < Test::Unit::TestCase
  class ADConfigParserForTesting
    attr_reader :realm

    def initialize(realm)
      @realm = realm
    end  
  end

  def setup
    @realm = 'test_realm'
    @ad_config = ADConfigParserForTesting.new(@realm)
    @provider = Proxy::ADRealm::Provider.new(@ad_config, 'keytab', 'principal')
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
