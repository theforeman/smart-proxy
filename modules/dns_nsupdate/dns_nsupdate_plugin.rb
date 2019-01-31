module ::Proxy::Dns::Nsupdate
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    validate_readable :dns_key

    capability "record_type_a"
    capability "record_type_aaaa"
    capability "record_type_cname"
    capability "record_type_ptr"
    capability "record_type_srv"

    load_classes ::Proxy::Dns::Nsupdate::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Dns::Nsupdate::PluginConfiguration
  end
end
