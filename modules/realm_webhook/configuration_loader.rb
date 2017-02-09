module Proxy::WebhookRealm
  class ConfigurationLoader
    def load_classes
      require 'realm_webhook/provider'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :realm_provider_impl, lambda {::Proxy::WebhookRealm::Provider.new(settings)}
    end
  end
end
