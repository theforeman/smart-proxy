require 'test_helper'
require 'json'
require 'ostruct'
require 'sinatra'
require 'puppet/puppet_api'

ENV['RACK_ENV'] = 'test'

class PuppetApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Puppet::Api.new
  end

  def setup
    apache = OpenStruct.new(:name => "apache::class", :module => "apache", :params => {:ensure => nil, :enable => true})
    apache.stubs(:to_s).returns(apache.name)
    @foo = OpenStruct.new(:name => "foo", :paths => ["/etc/puppet/modules/foo"], :classes => [apache])
    @bar = OpenStruct.new(:name => "bar", :paths => ["/etc/puppet/modules/common", "/etc/puppet/modules/bar"], :classes => [])
    @foo.stubs(:to_s).returns(@foo.name)
    @bar.stubs(:to_s).returns(@bar.name)
  end

  def test_api_gets_puppet_environments
    Proxy::Puppet::Environment.expects(:all).returns([@foo, @bar])
    get "/environments"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal ["foo", "bar"], data
  end

  def test_api_gets_single_puppet_environment
    Proxy::Puppet::Environment.expects(:find).with("foo").returns(@foo)
    get "/environments/foo"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "foo", data["name"]
    assert_equal ["/etc/puppet/modules/foo"], data["paths"]
  end

  def test_api_missing_single_puppet_environment
    Proxy::Puppet::Environment.expects(:find).with("unknown").returns(nil)
    get "/environments/unknown"
    assert_equal 404, last_response.status
  end

  def test_api_gets_puppet_environment_classes
    Proxy::Puppet::Environment.expects(:find).with("foo").returns(@foo)
    get "/environments/foo/classes"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal Array, data.class
    assert_equal "apache::class", data[0]["apache::class"]["name"]
    assert_equal "apache", data[0]["apache::class"]["module"]
    assert data[0]["apache::class"]["params"].include? "ensure"
    assert data[0]["apache::class"]["params"]["enable"]
  end
end
