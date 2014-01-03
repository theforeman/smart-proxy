require 'test_helper'
require 'helpers'
require 'puppetdb_api'
require 'json'
require 'open-uri'

ENV['RACK_ENV'] = 'test'

class PuppetDBApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    # Testing instructions
    #rake test TEST=test/puppetdb_api_test.rb
    SETTINGS.stubs(:puppetdb_host).returns("http://puppetdb:8080")
    @response  = ['factname1', 'factname2'].to_json

  end

  def test_api_can_get_fact_names
    Proxy::PuppetDB.any_instance.expects(:generic_query).with("fact-names", nil, nil).returns(@response)
    resp = get "/puppetdb/fact-names"
    assert resp.ok?, "Last response was not ok"
    data = JSON.parse(resp.body)
    assert_equal(['factname1', 'factname2'], data)
  end

  def test_api_can_get_nodes_with_query
    query = URI::encode 'query=["=", ["fact", "kernel"], "Linux"]'
    rubydata = JSON.parse(File.read 'test/fixtures/puppetdb/nodes.json')
    Proxy::PuppetDB.any_instance.expects(:generic_query).with("nodes",'["=", ["fact", "kernel"], "Linux"]', nil).returns(rubydata.to_json)
    resp = get "/puppetdb/nodes", query
    assert resp.ok?, "Last response was not ok"
    data = JSON.parse(resp.body)
    assert_equal(data, rubydata)

  end

  def test_api_gets_parameters_correctly
    rubydata = JSON.parse(File.read 'test/fixtures/puppetdb/nodes.json')
    query = URI::encode 'query=["=", ["fact", "kernel"], "Linux"]'
    Proxy::PuppetDB.any_instance.expects(:generic_query).with("nodes", '["=", ["fact", "kernel"], "Linux"]', nil).returns(rubydata)
    get '/puppetdb/nodes', query

  end

end

