module ::Proxy::Netbox
  class PluginConfiguration
    def load_classes
      require 'externalipam/netbox/netbox_client'
    end

    def load_dependency_injection_wirings(container, settings)
      container.dependency :externalipam_client, -> { ::Proxy::Netbox::NetboxClient.new(settings) }
    end
  end
end
