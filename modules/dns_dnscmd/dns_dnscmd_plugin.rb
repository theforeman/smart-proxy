module ::Proxy::Dns::Dnscmd
  class Plugin < ::Proxy::Provider
    plugin :dns_dnscmd, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    load_classes ::Proxy::Dns::Dnscmd::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Dns::Dnscmd::PluginConfiguration
  end
end
