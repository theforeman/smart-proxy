module ::Proxy::DHCP::Virsh
  class Plugin < ::Proxy::Provider
    plugin :dhcp_virsh, ::Proxy::VERSION

    requires :dhcp, ::Proxy::VERSION

    after_activation do
      require 'dhcp_virsh/dhcp_virsh_main'
      require 'dhcp_virsh/dependencies'
    end
  end
end
