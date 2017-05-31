module Proxy::WebhookRealm
  class Plugin < Proxy::Provider
    load_classes ::Proxy::WebhookRealm::ConfigurationLoader
    load_dependency_injection_wirings ::Proxy::WebhookRealm::ConfigurationLoader

    default_settings headers: {}, use_ssl: true, verify_ssl: true, signing: {enabled: false}, json_keys: {operation: "operation", hostname: "hostname", params: "params"}
    validate_presence :host, :port, :path

    plugin :realm_webhook, ::Proxy::VERSION
  end
end
