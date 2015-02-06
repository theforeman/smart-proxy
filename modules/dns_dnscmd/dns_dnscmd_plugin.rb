module ::Proxy::Dns::Dnscmd
  class Plugin < ::Proxy::Provider
    plugin :dns_dnscmd, ::Proxy::VERSION,
           :main_module => :dns, :factory => proc { |attrs| ::Proxy::Dns::Dnscmd::Record.record(attrs) }

    default_settings :enabled => true, :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_dnscmd/dns_dnscmd_main'
    end
  end
end
