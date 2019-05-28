require 'test_helper'
require 'json'
require 'templates/templates_unattended_api'
require 'templates/templates'
require 'webmock/test_unit'

class TemplatesUnattendedApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TemplatesUnattendedApi.new
  end

  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    @template_url = 'http://proxy.lan:8443'
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
    @args = { :token => "test-token" }
  end

  def test_api_can_return_templateserver
    get "/templateServer"
    assert last_response.ok?, "Last response was ok"
    data = JSON.parse(last_response.body)
    assert_equal(@template_url, data["templateServer"].to_s)
  end

  def test_api_passes_token_and_template_url
    stub_request(:get, "#{@foreman_url}/unattended/provision").with(query: {"token" => "test-token", "url" => @template_url}).to_return(:body => 'An API template')
    get "/provision", @args
    assert last_response.ok?, "Last response was ok"
    assert_match("An API template", last_response.body)
  end

  def test_api_can_ask_for_a_template
    stub_request(:get, "#{@foreman_url}/unattended/provision").with(query: {"url" => @template_url}).to_return(:body => 'An API template')
    get "/provision", {}
    assert last_response.ok?, "Last response was ok"
    assert_match("An API template", last_response.body)
  end

  def test_api_can_ask_for_a_hostgroup_template
    stub_request(:get, "#{@foreman_url}/unattended/kind/temp/hg").with(query: {"url" => @template_url}).to_return(:body => 'An API template')
    get "/kind/temp/hg", {}
    assert last_response.ok?, "Last response was ok"
    assert_match("An API template", last_response.body)
  end

  def test_api_can_ask_for_a_hostgroup_template_2
    stub_request(:get, "#{@foreman_url}/unattended/kind+space/temp+space/hg+space").with(query: {"url" => @template_url}).to_return(:body => 'An API template')
    get "/kind%20space/temp%20space/hg%20space", {}
    assert last_response.ok?, "Last response was ok"
    assert_match("An API template", last_response.body)
  end
end
