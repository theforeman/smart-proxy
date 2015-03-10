module ::Proxy::Dns::NsupdateGSS
  class Plugin < ::Proxy::Provider
    plugin :dns_nsupdate_gss, ::Proxy::VERSION,
           :main_module => :dns, :factory => proc { |attrs| ::Proxy::Dns::NsupdateGSS::Record.record(attrs) }

    default_settings :enabled => true, :dns_server => 'localhost', :dns_ttl => 86_400,
                     :dns_key => nil,
                     :dns_tsig_keytab => '/usr/share/foreman-proxy/dns.keytab',
                     :dns_tsig_principal => 'DNS/host.example.com@EXAMPLE.COM'

    requires :dns, ::Proxy::VERSION

    after_activation do
      require 'dns_nsupdate/dns_nsupdate_gss_main'
    end
  end
end
