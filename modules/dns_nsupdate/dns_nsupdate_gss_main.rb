require 'dns_nsupdate/dns_nsupdate_main'
require 'proxy/kerberos'

module Proxy::Dns::NsupdateGSS
  class Record < Proxy::Dns::Nsupdate::Record
    include Proxy::Kerberos
    attr_reader :tsig_keytab, :tsig_principal

    def initialize options = {}
      @tsig_keytab = options[:tsig_keytab]
      @tsig_principal = options[:tsig_principal]
      raise "Keytab not configured via dns_tsig_keytab for DNS GSS-TSIG support" unless tsig_keytab
      raise "Unable to read dns_tsig_keytab file at #{tsig_keytab}" unless File.exist?(tsig_keytab)
      raise "Kerberos principal required - check dns_tsig_principal setting" unless tsig_principal
      super(options)
    end

    protected

    def nsupdate_args
      "#{super} -g "
    end

    def nsupdate cmd
      init_krb5_ccache(tsig_keytab, tsig_principal) if cmd == "connect"
      super
    end
  end
end
