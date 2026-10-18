module ::Proxy::Phpipam
  class PluginConfiguration
    def load_classes
      require 'externalipam/phpipam/phpipam_client'
    end

    def load_dependency_injection_wirings(container, settings)
      container.dependency :externalipam_client, -> { ::Proxy::Phpipam::PhpipamClient.new(settings) }
    end
  end
end
