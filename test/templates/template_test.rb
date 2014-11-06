require 'test_helper'
require 'uri'
require 'net/http'
require 'mocha'
require 'templates/templates_plugin'
require 'templates/handler'
require 'webmock/test_unit'


class TemplateTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
  end

  def test_template_requests_return_data
    @expected_body = "my template"
    stub_request(:get, @foreman_url+'/unattended/provision?token=test-token').to_return(:status => [200, "OK"], :body => @expected_body)
    result =  Proxy::Templates::Handler.get_template('provision', 'test-token')
    assert_equal(@expected_body, result)
  end
end
