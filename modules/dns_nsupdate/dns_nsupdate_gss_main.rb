require 'dns_nsupdate/dns_nsupdate_main'
require 'proxy/kerberos'

module Proxy::Dns::NsupdateGSS
  class Record < Proxy::Dns::Nsupdate::Record
    include Proxy::Kerberos
    attr_reader :tsig_keytab, :tsig_principal

    def initialize(a_server = nil, a_ttl = nil)
      @tsig_keytab = ::Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_keytab
      @tsig_principal = ::Proxy::Dns::NsupdateGSS::Plugin.settings.dns_tsig_principal
      super(a_server || ::Proxy::Dns::NsupdateGSS::Plugin.settings.dns_server,
            a_ttl || ::Proxy::Dns::Plugin.settings.dns_ttl)
    end

    def nsupdate_args
      " -g "
    end

    def nsupdate_connect cmd
      init_krb5_ccache(tsig_keytab, tsig_principal)
      super
    end
  end
end
