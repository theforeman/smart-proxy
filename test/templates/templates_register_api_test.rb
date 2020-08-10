require 'test_helper'
require 'templates/templates_register_api'
require 'templates/templates'
require 'webmock/test_unit'

class TemplatesRegisterApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TemplatesRegisterApi.new
  end

  def setup
    @foreman_url = 'http://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    @template_url = 'http://smart-proxy.example.com'
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
  end

  def test_api_global_registration
    stub_request(:get, "#{@foreman_url}/register").with(query: {"url" => @template_url}).to_return(:body => 'GRT content')
    get "/", {}
    assert last_response.ok?, "Last response was ok"
    assert_match("GRT content", last_response.body)
  end
end
