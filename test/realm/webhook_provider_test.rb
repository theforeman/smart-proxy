# -*- coding: utf-8 -*-
require 'test_helper'
require 'realm_webhook/provider'

class WebhookTest < Test::Unit::TestCase
  DEFAULT_CONFIG = {
    host: "localhost",
    port: 9999,
    path: "/hooks",
    use_ssl: true,
    verify_ssl: false,
    headers: {},
    signing: {
      enabled: false
    },
    json_keys: {
      operation: "operation",
      hostname: "hostname",
      params: "params"
    }
  }
  def test_find
    provider = Proxy::WebhookRealm::Provider.new(DEFAULT_CONFIG)
    assert_equal provider.find("Host"), {}
  end

  def test_construct_request
    provider = Proxy::WebhookRealm::Provider.new(DEFAULT_CONFIG)
    params = {"a" => "a", "b" => "b"}
    req = provider.construct_request("foo", "bar.host", params)
    assert_equal JSON.parse(req.body), {"operation" => "foo", "hostname" => "bar.host", "params" => params}
    assert_equal req["Content-Type"], "application/json"
    assert_equal req["Accept"], "application/json"
    assert_equal req["User-Agent"], "Foreman Smart Proxy"
    assert_equal req.path, "/hooks"

    config = DEFAULT_CONFIG.merge({
      headers: {
        "X-ACME-Auth" => "token",
        "Content-Type" => "application/vnd.acme.foo+json"
      },
      signing: {
        enabled: true,
        algorithm: "sha1",
        secret: "some_secret",
        header_name: "X-ACME-SIGNATURE"
      }
    })
    provider = Proxy::WebhookRealm::Provider.new(config)
    req = provider.construct_request "bar", "foo.host", params
    assert_equal JSON.parse(req.body), {"operation" => "bar", "hostname" => "foo.host", "params" => params}
    assert_equal req["Content-Type"], "application/vnd.acme.foo+json"
    assert_equal req["Accept"], "application/json"
    assert_equal req["User-Agent"], "Foreman Smart Proxy"
    assert_equal req["X-ACME-Auth"], "token"
    assert_equal req["X-ACME-SIGNATURE"], "sha1=65167b13f5e9c5bd5f4cad9ceba1adee45ff7327"
  end

  def test_create
    provider = Proxy::WebhookRealm::Provider.new(DEFAULT_CONFIG)
    provider.expects(:request).with("create", "a_host", {"a" => "a"}).returns("somedata")
    assert_equal "somedata", provider.create("test", 'a_host', {"a" => "a"})
  end

  def test_delete
    provider = Proxy::WebhookRealm::Provider.new(DEFAULT_CONFIG)
    provider.expects(:request).with("delete", "a_host", {}).returns("somedata")
    assert_equal "somedata", provider.delete("test", 'a_host')
  end

  def test_configure_webhook
    provider = Proxy::WebhookRealm::Provider.new(DEFAULT_CONFIG)
    wh = provider.configure_webhook
    assert_equal wh.port, 9999
    assert_equal wh.address, "localhost"
    assert_equal wh.use_ssl?, true
    assert_equal wh.verify_mode, OpenSSL::SSL::VERIFY_NONE
  end
end
