require 'test_helper'
require 'puppetdb'
require 'proxy/puppetdb'

class PuppetDBTest < Test::Unit::TestCase
  def setup
    SETTINGS.stubs(:puppetdb_host).returns("http://puppetdb:8080")
    SETTINGS.stubs(:ssl_private_key).returns('test/fixtures/certs/private_key.pem')
    SETTINGS.stubs(:ssl_certificate).returns('test/fixtures/certs/certificate.pem')
    SETTINGS.stubs(:ssl_ca_file).returns('test/fixtures/certs/ca.pem')

    @proxy = Proxy::PuppetDB.new
    @response  = mock()
    Net::HTTP.any_instance.stubs(:get).returns(@response)


  end


  def test_should_retrieve_list_of_facts
    @response.stubs(:body).returns(['factname1', 'factname2'].to_json)
    response = @proxy.generic_query('fact-names')
    assert_equal(response,JSON.generate(['factname1', 'factname2']) )
  end

  def test_should_retrieve_fact_value_from_specific_host
    @response.stubs(:body).returns(['factname1', 'factname2'].to_json)
    response = @proxy.generic_query('nodes/testname/facts')
    assert_equal(response,JSON.generate(['factname1', 'factname2']) )
  end

  def test_should_retrieve_fact_value_from_multiple_hosts
    @response.stubs(:body).returns(['factname1', 'factname2'].to_json)
    response = @proxy.generic_query('facts', 'query=["=", ["fact", "kernel"], "Linux"]')
    assert_equal(response,JSON.generate(['factname1', 'factname2']) )
  end

  def test_should_raise_exception_when_settings_are_bad
    SETTINGS.stubs(:ssl_private_key).returns('test/foo/certs/private_key.pem')
    SETTINGS.stubs(:puppetdb_host).returns("https://puppetdb:8080")
    proxyclient = Proxy::PuppetDB.new

    assert_raise RuntimeError do
      proxyclient.generic_query('facts', 'query=["=", ["fact", "kernel"], "Linux"]')
    end
  end

  def test_should_create_ssl_based_client
    SETTINGS.stubs(:puppetdb_host).returns("https://puppetdb:8080")
    @response.stubs(:body).returns(['factname1', 'factname2'].to_json)
    proxyclient = Proxy::PuppetDB.new
    response = proxyclient.generic_query('facts', 'query=["=", ["fact", "kernel"], "Linux"]')
    assert_equal(response,JSON.generate(['factname1', 'factname2']) )

  end




end