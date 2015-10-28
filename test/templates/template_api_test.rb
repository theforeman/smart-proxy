require 'test_helper'
require 'json'
require 'templates/templates_api'
require 'templates/templates'

class TemplateApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TemplatesApi.new
  end

  def setup
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns("someproxy:8443")
    Proxy::SETTINGS.stubs(:foreman_url).returns("someproxy:8443")
    @args = { :token => "test-token" }
  end

  def test_api_can_return_templateserver
    get "/templateServer"
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("someproxy:8443", data["templateServer"].to_s)
  end

  def test_api_can_ask_for_a_template
    Proxy::Templates::TemplateProxyRequest.any_instance.expects(:get_template).returns("An API template")
    get "/provision", @args
    assert last_response.ok?, "Last response was not ok"
    assert_match("An API template", last_response.body)
  end

end
