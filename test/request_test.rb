require 'test_helper'
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
