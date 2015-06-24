module ::Proxy::DHCP::ISC
  class Plugin < ::Proxy::Provider
    # :provider_class is optional and can be omitted in this case, as it follows the naming convention: "plugin namespace::Provider"
    plugin :dhcp_isc, ::Proxy::VERSION, :provider_class => "::Proxy::DHCP::ISC::Provider"

    default_settings :config => '/etc/dhcp/dhcpd.conf', :leases => '/var/lib/dhcpd/dhcpd.leases',
                     :omapi_port => '7911'

    requires :dhcp, ::Proxy::VERSION
    validate_readable :config, :leases

    after_activation do
      require 'dhcp_isc/dhcp_isc_main'
      require 'dhcp_isc/dependencies'
    end
  end
end
