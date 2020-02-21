module ::Proxy::Dns::Nsupdate
  class PluginConfiguration
    def load_classes
      require 'dns_common/dns_common'
      require 'dns_nsupdate/dns_nsupdate_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :dns_provider, -> {::Proxy::Dns::Nsupdate::Record.new(settings[:dns_server], settings[:dns_ttl], settings[:dns_key]) }
    end
  end
end
