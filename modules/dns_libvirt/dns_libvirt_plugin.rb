module ::Proxy::Dns::Libvirt
  class Plugin < ::Proxy::Provider
    plugin :dns_libvirt, ::Proxy::VERSION

    requires :dns, ::Proxy::VERSION

    default_settings :url => "qemu:///system", :network => 'default'

    after_activation do
      require 'dns_libvirt/dns_libvirt_main'
      require 'dns_libvirt/dependencies'
    end
  end
end
