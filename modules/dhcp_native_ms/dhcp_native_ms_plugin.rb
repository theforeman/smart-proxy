module ::Proxy::DHCP::NativeMS
  class Plugin < ::Proxy::Provider
    plugin :dhcp_native_ms, ::Proxy::VERSION

    default_settings :disable_ddns => true

    requires :dhcp, ::Proxy::VERSION

    load_classes ::Proxy::DHCP::NativeMS::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::DHCP::NativeMS::PluginConfiguration
  end
end
