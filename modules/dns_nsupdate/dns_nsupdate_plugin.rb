module ::Proxy::Dns::Nsupdate
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    validate_readable :dns_key

    load_classes ::Proxy::Dns::Nsupdate::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Dns::Nsupdate::PluginConfiguration
  end
end
