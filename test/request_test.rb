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
    Proxy::Templates::Plugin.settings.stubs(:template_url).returns(@template_url)
    @request = Proxy::HttpRequest::ForemanRequest.new
  end

  def test_get
    stub_request(:get, @foreman_url+'/path').to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_get("/path")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_get_with_headers
    stub_request(:get, @foreman_url+'/path?a=b').with(:headers => {"h1" => "header"}).to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_get "/path", {"a" => "b"}, "h1" => "header"
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end

  def test_post
    stub_request(:post, @foreman_url+'/path').with(:body => "body").to_return(:status => [200, 'OK'], :body => "body")
    proxy_req = @request.request_factory.create_post("/path", "body")
    result = @request.send_request(proxy_req)
    assert_equal("body", result.body)
  end
end
