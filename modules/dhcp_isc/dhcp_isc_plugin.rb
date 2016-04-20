module ::Proxy::DHCP::ISC
  class Plugin < ::Proxy::Provider
    plugin :dhcp_isc, ::Proxy::VERSION

    default_settings :config => '/etc/dhcp/dhcpd.conf', :leases => '/var/lib/dhcpd/dhcpd.leases',
                     :omapi_port => '7911'

    requires :dhcp, ::Proxy::VERSION
    validate_readable :config, :leases

    load_classes ::Proxy::DHCP::ISC::PluginConfiguration
    load_programmable_settings ::Proxy::DHCP::ISC::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::DHCP::ISC::PluginConfiguration

    start_services :leases_observer
  end
end
