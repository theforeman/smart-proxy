require 'test_helper'
require 'faraday'
require 'uri'
require 'net/http'
require 'mocha'
require 'templates/templates_plugin'
require "proxy/util"
require 'proxy/request'
require 'webmock/test_unit'

class RequestTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    Proxy::SETTINGS.stubs(:foreman_request_timeout).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_open_timeout).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_ssl_ca).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_ca_file).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_ssl_cert).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_certificate).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_ssl_key).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_private_key).returns(nil)
    @template_url = 'http://proxy.lan:8443'
    Proxy::Templates::Plugin.load_test_settings(:template_url => @template_url)
    @request = Proxy::HttpRequest::ForemanRequest.new
  end

  def test_get
    stub_request(:get, @foreman_url + '/path').to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_get("/path")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_get_with_headers
    stub_request(:get, @foreman_url + '/path?a=b').with(:headers => {"h1" => "header"}).to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_get("/path", {"a" => "b"}, "h1" => "header")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_get_with_nested_params
    stub_request(:get, @foreman_url + '/register?activation_keys%5B%5D=ac_AlmaLinux8&location_id=2&organization_id=1&repo_data%5B%5D%5Brepo%5D=repo1&repo_data%5B%5D%5Brepo_gpg_key_url%5D=key1&repo_data%5B%5D%5Brepo%5D=repo2&repo_data%5B%5D%5Brepo_gpg_key_url%5D=key2&update_packages=false')
      .with(:headers => {"h1" => "header"}).to_return(status: 200, body: "body", headers: {})
    request_params =
      { "activation_keys" => ["ac_AlmaLinux8"],
        "location_id" => "2",
        "organization_id" => "1",
        "repo_data" => [
          {"repo" => "repo1", "repo_gpg_key_url" => "key1"},
          {"repo" => "repo2", "repo_gpg_key_url" => "key2"},
        ],
        "update_packages" => "false" }
    proxy_req = @request.request_factory.create_get("/register", request_params, "h1" => "header")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_post
    stub_request(:post, @foreman_url + '/path').with(:body => "body").to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_post("/path", "body")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_read_timeout_applied_when_foreman_request_timeout_configured
    Proxy::SETTINGS.stubs(:foreman_request_timeout).returns(120)
    request = Proxy::HttpRequest::ForemanRequest.new

    assert_equal 120, request.http.read_timeout
    assert_equal 120, request.connection.options.timeout
  end

  def test_read_timeout_uses_default_when_foreman_request_timeout_not_configured
    default_timeout = Net::HTTP.new('example.com').read_timeout
    request = Proxy::HttpRequest::ForemanRequest.new

    assert_equal default_timeout, request.http.read_timeout
  end

  def test_open_timeout_applied_when_foreman_open_timeout_configured
    Proxy::SETTINGS.stubs(:foreman_open_timeout).returns(30)
    request = Proxy::HttpRequest::ForemanRequest.new

    assert_equal 30, request.http.open_timeout
    assert_equal 30, request.connection.options.open_timeout
  end

  def test_open_timeout_uses_net_http_default_when_foreman_open_timeout_not_configured
    default_timeout = Net::HTTP.new('example.com').open_timeout
    request = Proxy::HttpRequest::ForemanRequest.new

    assert_equal default_timeout, request.http.open_timeout
    assert_equal default_timeout, request.connection.options.open_timeout
  end

  def test_connection_uses_faraday
    request = Proxy::HttpRequest::ForemanRequest.new

    assert_kind_of Faraday::Connection, request.connection
  end

  def test_post_with_nested_params
    stub_request(:post, @foreman_url + '/register?activation_keys%5B%5D=ac_AlmaLinux8&location_id=2&organization_id=1&repo_data%5B%5D%5Brepo%5D=repo1&repo_data%5B%5D%5Brepo_gpg_key_url%5D=key1&repo_data%5B%5D%5Brepo%5D=repo2&repo_data%5B%5D%5Brepo_gpg_key_url%5D=key2&update_packages=false')
      .to_return(status: 200, body: "body", headers: {h1: "header"})
    request_params =
      { "activation_keys" => ["ac_AlmaLinux8"],
        "location_id" => "2",
        "organization_id" => "1",
        "repo_data" => [
          {"repo" => "repo1", "repo_gpg_key_url" => "key1"},
          {"repo" => "repo2", "repo_gpg_key_url" => "key2"},
        ],
        "update_packages" => "false" }
    proxy_req = @request.request_factory.create_post "/register", {"body" => "body"}, {"h1" => "header"}, request_params
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end
end
