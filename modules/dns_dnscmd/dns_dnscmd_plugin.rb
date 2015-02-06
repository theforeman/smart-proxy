module ::Proxy::Dns::Dnscmd
  class Plugin < ::Proxy::Provider
    plugin :dns_dnscmd, ::Proxy::VERSION,
           :factory => proc { |attrs| ::Proxy::Dns::Dnscmd::Record.record(attrs) }

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_dnscmd/dns_dnscmd_main'
    end
  end
end
