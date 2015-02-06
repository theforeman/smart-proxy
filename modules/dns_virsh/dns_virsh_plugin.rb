module ::Proxy::Dns::Virsh
  class Plugin < ::Proxy::Provider
    plugin :dns_virsh, ::Proxy::VERSION,
           :factory => proc { |attrs| ::Proxy::Dns::Virsh::Record.record(attrs) }

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_virsh/dns_virsh_main'
    end
  end
end
