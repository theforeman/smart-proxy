module ::Proxy::Dns::Dnscmd
  class PluginConfiguration
    def load_classes
      require 'dns_common/dns_common'
      require 'dns_dnscmd/dns_dnscmd_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :dns_provider, -> {::Proxy::Dns::Dnscmd::Record.new(settings[:dns_server], settings[:dns_ttl]) }
    end
  end
end
