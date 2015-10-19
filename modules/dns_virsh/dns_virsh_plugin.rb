module ::Proxy::Dns::Virsh
  class Plugin < ::Proxy::Provider
    plugin :dns_virsh, ::Proxy::VERSION

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_virsh/dns_virsh_main'
      require 'dns_virsh/dependencies'
    end
  end
end
