module ::Proxy::Dns::NsupdateGSS
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate_gss, ::Proxy::VERSION

    default_settings :dns_server => 'localhost',
                     :dns_tsig_keytab => '/usr/share/foreman-proxy/dns.keytab',
                     :dns_tsig_principal => 'DNS/host.example.com@EXAMPLE.COM'

    requires :dns, ::Proxy::VERSION

    validate_readable :dns_tsig_keytab

    after_activation do
      require 'dns_nsupdate/dns_nsupdate_gss_main'
      require 'dns_nsupdate/nsupdate_gss_dependencies'
    end
  end
end
