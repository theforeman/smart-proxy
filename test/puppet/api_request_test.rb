require 'test_helper'
require 'puppet_proxy_common/api_request'
require 'puppet_proxy_puppet_api/v3_api_request'
require 'webmock/test_unit'

class PuppetApiRequestTest < Test::Unit::TestCase
  def test_get_environments_apiv3
    stub_request(:get, 'http://localhost:8140/puppet/v3/environments').to_return(:body => '{"environments":{}}')
    result = Proxy::PuppetApi::EnvironmentsApiv3.new('http://localhost:8140', nil, nil, nil).find_environments
    assert_equal({"environments" => {}}, result)
  end

  def test_list_classes_apiv3
    return_json = '[{"stdlib": {}}]'
    stub_request(:get, 'http://localhost:8140/puppet/v3/resource_types/*?kind=class&environment=testing').to_return(:body => return_json)
    result = Proxy::PuppetApi::ResourceTypeApiv3.new('http://localhost:8140', nil, nil, nil).list_classes('testing', 'class')
    assert_equal([{'stdlib' => {}}], result)
  end

  def test_list_classes_apiv3_returns_an_empty_list_if_no_classes_were_found
    stub_request(:get, 'http://localhost:8140/puppet/v3/resource_types/*?kind=class&environment=testing').to_return(:status => 404, :body => "Could not find instances in resource_type with '*'")
    result = Proxy::PuppetApi::ResourceTypeApiv3.new('http://localhost:8140', nil, nil, nil).list_classes('testing', 'class')
    assert_equal([], result)
  end
end
