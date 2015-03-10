module ::Proxy::Dns::Virsh
  class Plugin < ::Proxy::Provider
    plugin :dns_virsh, ::Proxy::VERSION,
           :main_module => :dns, :factory => proc { |attrs| ::Proxy::Dns::Virsh::Record.record(attrs) }

    default_settings :enabled => true

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_virsh/dns_virsh_main'
    end
  end
end
