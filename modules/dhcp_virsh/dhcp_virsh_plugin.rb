module ::Proxy::DHCP::Virsh
  class Plugin < ::Proxy::Provider
    plugin :dhcp_virsh, ::Proxy::VERSION

    requires :dhcp, ::Proxy::VERSION

    default_settings :network => 'default', :leases => '/var/lib/libvirt/dnsmasq/virbr0.status'

    after_activation do
      require 'dhcp_virsh/dhcp_virsh_main'
      require 'dhcp_virsh/dependencies'
    end
  end
end
