require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/api_request'
require 'webmock/test_unit'

class PuppetApiRequestTest < Test::Unit::TestCase
  def fixtures
    File.expand_path(File.join(File.dirname(__FILE__), '.', 'fixtures', 'authentication'))
  end

  def test_ssl_config
    stub_request(:get, 'https://puppet.example.com:8140/v2.0/environments').to_return(:body => '{}')
    Proxy::Puppet::EnvironmentsApi.new(
        'https://puppet.example.com:8140',
        File.join(fixtures, 'puppet_ca.pem'),
        File.join(fixtures, 'foreman.example.com.cert'),
        File.join(fixtures, 'foreman.example.com.key')).find_environments
  end

  def test_api_error
    stub_request(:get, 'http://puppet.example.com:8140/v2.0/environments').to_return(:status => 403, :body => 'Not allowed')
    assert_raise ::Proxy::Error::HttpError do
      api = Proxy::Puppet::EnvironmentsApi.new('http://puppet.example.com:8140', nil, nil, nil)
      api.handle_response(api.send_request('v2.0/environments'), "an error messsage")
    end
  end

  def test_parses_json_response
    string_json = '[{"stdlib": {"module": null,"name": "stdlib","params": {}}}]'
    stub_request(:get, 'http://localhost:8140/puppet/v3/resource_types/*?environment=testing').to_return(:body => string_json)

    api = Proxy::Puppet::EnvironmentsApi.new('http://localhost:8140', nil, nil, nil)
    response = api.handle_response(api.send_request('puppet/v3/resource_types/*?environment=testing'), '')

    assert_equal(JSON.load(string_json), response)
  end

  def test_get_environments_apiv2
    stub_request(:get, 'http://localhost:8140/v2.0/environments').to_return(:body => '{"environments":{}}')
    result = Proxy::Puppet::EnvironmentsApi.new('http://localhost:8140', nil, nil, nil).find_environments
    assert_equal({"environments" => {}}, result)
  end

  def test_get_environments_apiv3
    stub_request(:get, 'http://localhost:8140/puppet/v3/environments').to_return(:body => '{"environments":{}}')
    result = Proxy::Puppet::EnvironmentsApiv3.new('http://localhost:8140', nil, nil, nil).find_environments
    assert_equal({"environments" => {}}, result)
  end

  def test_list_classes_apiv3
    return_json = '[{"stdlib": {}}]'
    stub_request(:get, 'http://localhost:8140/puppet/v3/resource_types/*?kind=class&environment=testing').to_return(:body => return_json)
    result = Proxy::Puppet::ResourceTypeApiv3.new('http://localhost:8140', nil, nil, nil).list_classes('testing', 'class')
    assert_equal([{'stdlib' => {}}], result)
  end
end
