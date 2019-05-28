require 'test_helper'
require 'json'
require 'templates/templates_userdata_api'
require 'templates/templates'
require 'webmock/test_unit'

class TemplatesApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TemplatesUserdataApi.new
  end

  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    @template_url = 'http://proxy.lan:8443'
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
    @args = { :token => "test-token" }
  end

  def test_api_can_ask_for_a_cloud_init_template
    stub_request(:get, "#{@foreman_url}/userdata/user-data").with(query: {"url" => @template_url}).to_return(:body => 'A user-data template')
    get "/user-data", {}
    assert last_response.ok?, "Last response was ok"
    assert_match("A user-data template", last_response.body)
  end
end
