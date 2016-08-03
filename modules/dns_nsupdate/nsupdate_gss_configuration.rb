module ::Proxy::Dns::NsupdateGSS
  class PluginConfiguration
    def load_classes
      require 'dns_common/dns_common'
      require 'dns_nsupdate/dns_nsupdate_gss_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :dns_provider,
                                    lambda { ::Proxy::Dns::NsupdateGSS::Record.new(settings[:dns_server], settings[:dns_ttl], settings[:dns_tsig_keytab], settings[:dns_tsig_principal]) }
    end
  end
end
