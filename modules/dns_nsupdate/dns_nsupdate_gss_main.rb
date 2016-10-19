require 'dns_nsupdate/dns_nsupdate_main'
require 'proxy/kerberos'

module Proxy::Dns::NsupdateGSS
  class Record < Proxy::Dns::Nsupdate::Record
    include Proxy::Kerberos
    attr_reader :tsig_keytab, :tsig_principal

    def initialize(a_server, a_ttl, a_rewritemap, tsig_keytab, tsig_principal)
      @tsig_keytab = tsig_keytab
      @tsig_principal = tsig_principal
      super(a_server, a_ttl, a_rewritemap, nil)
    end

    def nsupdate_args
      " -g "
    end

    def nsupdate_connect
      init_krb5_ccache(tsig_keytab, tsig_principal)
      super
    end
  end
end
