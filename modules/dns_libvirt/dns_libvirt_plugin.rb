module ::Proxy::Dns::Libvirt
  class Plugin < ::Proxy::Provider
    plugin :dns_libvirt, ::Proxy::VERSION

    requires :dns, ::Proxy::VERSION

    default_settings :url => "qemu:///system", :network => 'default'
    validate :url, :url => true

    load_classes ::Proxy::Dns::Libvirt::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Dns::Libvirt::PluginConfiguration
  end
end
