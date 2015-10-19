module ::Proxy::Dns::Dnscmd
  class Plugin < ::Proxy::Provider
    plugin :dns_dnscmd, ::Proxy::VERSION

    default_settings :dns_server => 'localhost'

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_dnscmd/dns_dnscmd_main'
      require 'dns_dnscmd/dependencies'
    end
  end
end
