module ::Proxy::DHCP::Libvirt
  class Plugin < ::Proxy::Provider
    plugin :dhcp_libvirt, ::Proxy::VERSION

    requires :dhcp, ::Proxy::VERSION

    default_settings :url => "qemu:///system", :network => 'default'

    after_activation do
      require 'dhcp_libvirt/dhcp_libvirt_main'
      require 'dhcp_libvirt/dependencies'
    end
  end
end
