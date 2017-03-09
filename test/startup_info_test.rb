require 'test_helper'
require 'net/http'
require 'mocha'
require 'webmock/test_unit'
require 'proxy/startup_info'

class StartupInfoTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
  end

  def test_put_features
    proxy_name = "test-proxy.example.com"
    Socket.stubs(:gethostname).returns("test-proxy.example.com")
    stub_request(:put, @foreman_url+'/api/v2/smart_proxies/startup_refresh').to_return(:status => [200, 'OK'],
                                                                                       :body => proxy_name)
    result = Proxy::StartupInfo.new.put_features
    assert_equal proxy_name, result.body
  end
end
