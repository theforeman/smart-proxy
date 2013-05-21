require 'proxy/dns/nsupdate'
require 'rkerberos'

module Proxy::DNS
  class NsupdateGSS < Nsupdate
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
      init_krb5_ccache if cmd == "connect"
      super
    end

    private

    def init_krb5_ccache
      krb5 = Kerberos::Krb5.new
      ccache = Kerberos::Krb5::CredentialsCache.new
      logger.info "Requesting credentials for Kerberos principal #{tsig_principal} using keytab #{tsig_keytab}"
      begin
        krb5.get_init_creds_keytab tsig_principal, tsig_keytab, nil, ccache
      rescue => e
        logger.error "Failed to initialise credential cache from keytab: #{e}"
        raise Proxy::DNS::Error.new("Unable to initialise Kerberos: #{e}")
      end
      logger.debug "Kerberos credential cache initialised with principal: #{ccache.primary_principal}"
    end
  end
end
