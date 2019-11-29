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
end
