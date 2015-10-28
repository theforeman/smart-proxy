require 'test_helper'
require 'uri'
require 'net/http'
require 'mocha'
require 'templates/templates_plugin'
require 'templates/template_proxy_request'
require 'webmock/test_unit'


class TemplateProxyRequestTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    @template_url = 'http://proxy.lan:8443'
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
    @request_env = {
      'REMOTE_ADDR' => '1.2.3.4'
    }
  end

  def test_header_extraction_empty
    tpr = Proxy::Templates::TemplateProxyRequest.new
    res = tpr.extract_request_headers({})
    assert_equal({}, res)
  end

  def test_header_extraction_data
    tpr = Proxy::Templates::TemplateProxyRequest.new
    res = tpr.extract_request_headers('HTTP_H1' => 'h1')
    assert_equal({'H1' => 'h1'}, res)
  end

  def test_header_extraction_http_version_gets_removed
    tpr = Proxy::Templates::TemplateProxyRequest.new
    res = tpr.extract_request_headers('HTTP_VERSION' => '1.1')
    assert_equal({}, res)
  end

  def test_template_requests_return_data_and_contain_template_url
    @expected_body = "my template"
    args = { :token => "test-token" }
    stub_request(:get, @foreman_url+'/unattended/provision?token=test-token&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::TemplateProxyRequest.new.get_template('provision', @request_env, args)
    assert_equal(@expected_body, result)
  end

  def test_template_requests_pass_static_flag_to_foreman
    @expected_body = "my template"
    args = { :token => "test-token", :static => "true" }
    stub_request(:get, @foreman_url+'/unattended/provision?static=true&token=test-token&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::TemplateProxyRequest.new.get_template('provision', @request_env, args)
    assert_equal(@expected_body, result)
  end

  def test_template_requests_with_macaddress
    @expected_body = "my template"
    args = { :mac => "aa:bb:cc:dd:ee:ff" }
    stub_request(:get, @foreman_url+'/unattended/provision?mac=aa:bb:cc:dd:ee:ff&url='+@template_url).to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::TemplateProxyRequest.new.get_template('provision', @request_env, args)
    assert_equal(@expected_body, result)
  end

  def test_template_requests_with_rhn_headers
    @expected_body = "my template"
    @request_env['HTTP_X_RHN_PROVISIONING_MAC_0'] = 'aa:bb:cc:dd:ee:ff'
    args = { :token => "test-token" }
    stub_request(:get, @foreman_url+'/unattended/provision?token=test-token&url='+@template_url).
      with(:headers => {'X-Forwarded-For'=>'1.2.3.4, proxy.lan', 'X-Rhn-Provisioning-Mac-0'=>'aa:bb:cc:dd:ee:ff'}).
      to_return(:status => [200, 'OK'], :body => @expected_body)
    result = Proxy::Templates::TemplateProxyRequest.new.get_template('provision', @request_env, args)
    assert_equal(@expected_body, result)
  end
end
