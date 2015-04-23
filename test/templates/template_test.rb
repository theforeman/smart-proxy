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
    @template_url = 'http://proxy.lan:8443'
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
  end

  def test_template_requests_return_data_and_contain_template_url
    @expected_body = "my template"
    args = { :token => "test-token" }
    stub_request(:get, @foreman_url+'/unattended/provision?token=test-token&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::Handler.get_template('provision', args)
    assert_equal(@expected_body, result)
  end

  def test_template_requests_pass_static_flag_to_foreman
    @expected_body = "my template"
    args = { :token => "test-token", :static => "true" }
    stub_request(:get, @foreman_url+'/unattended/provision?static=true&token=test-token&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::Handler.get_template('provision', args)
    assert_equal(@expected_body, result)
  end

  def test_template_requests_with_macaddress
    @expected_body = "my template"
    args = { :mac => "aa:bb:cc:dd:ee:ff" }
    stub_request(:get, @foreman_url+'/unattended/provision?mac=aa:bb:cc:dd:ee:ff&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::Handler.get_template('provision', args)
    assert_equal(@expected_body, result)
  end
end
