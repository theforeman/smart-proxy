require 'test_helper'
require 'helpers'
require 'template_api'
require 'json'

class TemplateApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    @args = { :token => "test-token" }
  end

  def test_api_can_return_templateserver
    SETTINGS.stubs(:template_url).returns("someproxy:8443")
    get "/unattended/templateServer"
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("someproxy:8443", data["templateServer"].to_s)
  end

  def test_api_can_ask_for_a_template
    Proxy::Template::Handler.stubs(:get_template).returns("An API template")
    get "/unattended/provision", @args
    assert last_response.ok?, "Last response was not ok"
    assert_match("An API template", last_response.body)
  end

end
