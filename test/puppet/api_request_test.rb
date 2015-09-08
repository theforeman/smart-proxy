require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/api_request'
require 'webmock/test_unit'

class PuppetApiRequestTest < Test::Unit::TestCase
  def setup
    Puppet.expects(:[]).with(:certname).returns('puppet.example.com')
    Facter.stubs(:value).with(:fqdn).returns('puppet.example.com')
  end

  def fixtures
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'fixtures', 'authentication'))
  end

  def test_get_environments
    Proxy::Puppet::Plugin::settings.stubs(:puppet_url).returns('http://localhost:8140')
    stub_request(:get, 'http://localhost:8140/v2.0/environments').to_return(:body => '{"environments":{}}')
    result = Proxy::Puppet::EnvironmentsApi.new.find_environments
    assert_equal({"environments" => {}}, result)
  end

  def test_ssl_config
    Proxy::Puppet::Plugin::settings.expects(:puppet_ssl_ca).at_least_once.returns(File.join(fixtures, 'puppet_ca.pem'))
    Proxy::Puppet::Plugin::settings.expects(:puppet_ssl_cert).at_least_once.returns(File.join(fixtures, 'foreman.example.com.cert'))
    Proxy::Puppet::Plugin::settings.expects(:puppet_ssl_key).at_least_once.returns(File.join(fixtures, 'foreman.example.com.key'))
    stub_request(:get, 'https://puppet.example.com:8140/v2.0/environments').to_return(:body => '{}')
    Proxy::Puppet::EnvironmentsApi.new.find_environments
  end

  def test_api_error
    Proxy::Puppet::Plugin::settings.stubs(:puppet_url).returns('http://puppet.example.com:8140')
    stub_request(:get, 'http://puppet.example.com:8140/v2.0/environments').to_return(:status => 403, :body => 'Not allowed')
    assert_raise Proxy::Puppet::ApiError do
      Proxy::Puppet::EnvironmentsApi.new.find_environments
    end
  end
end
