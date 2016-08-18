module ::Proxy::DHCP::ISC
  class Plugin < ::Proxy::Provider
    plugin :dhcp_isc, ::Proxy::VERSION

    default_settings :config4 => '/etc/dhcp/dhcpd.conf',
                     :leases4 => '/var/lib/dhcpd/dhcpd.leases',
                     :omapi_port => '7911',
                     :config6 => '/etc/dhcp/dhcpd6.conf',
                     :leases6 => '/var/lib/dhcpd/dhcpd6.leases'

    requires :dhcp, ::Proxy::VERSION
    validate_readable :config4, :leases4, :config6, :leases6

    load_classes ::Proxy::DHCP::ISC::PluginConfiguration
    load_programmable_settings ::Proxy::DHCP::ISC::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::DHCP::ISC::PluginConfiguration

    start_services :leases_observer4, :leases_observer6
  end
end
