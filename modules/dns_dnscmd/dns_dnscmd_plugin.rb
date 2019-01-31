module ::Proxy::Dns::Dnscmd
  class Plugin < ::Proxy::Provider
    plugin :dns_dnscmd, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    capability "record_type_a"
    capability "record_type_aaaa"
    capability "record_type_cname"
    capability "record_type_ptr"

    load_classes ::Proxy::Dns::Dnscmd::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Dns::Dnscmd::PluginConfiguration
  end
end
