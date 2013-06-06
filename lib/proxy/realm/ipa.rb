module Proxy::Realm
  class IPA < Client

    include Proxy::Kerberos
    include Proxy::Util

    attr_accessor :tsig_keytab, :tsig_principal, :fqdn
    attr_reader :pwd, :output

    def initialize( options = {})
      @fqdn = options[:fqdn]
      @tsig_keytab = options[:tsig_keytab]
      @tsig_principal = options[:tsig_principal]
      raise "Keytab not configured via ipa_tsig_keytab for IPA GSS-TSIG support" unless tsig_keytab
      raise "Unable to read ipa_tsig_keytab file at #{tsig_keytab}" unless File.exist?(tsig_keytab)
      raise "Kerberos principal required - check ipa_tsig_principal setting" unless tsig_principal
      init_krb5_ccache @tsig_keytab, @tsig_principal
      logger.debug "ipa: created client obj for #{@fqdn}"
    end

    def host_find
      logger.debug "ipa: trying to find #{@fqdn}"
      ipa "host-find"
    end

    def host_add
      pwd = mk_pwd
      ipa "host-add", "--password=#{pwd}"
      pwd
    end

    def host_del
      ipa "host-del"
    end

    protected

    def ipa_args
      args = " "
      args = "--password=secret "
      args
    end

    def ipa(cmd, args=nil)
      @output = nil
      find_ipa if @ipa.nil?
      ipa_cmd = "#{@ipa} #{cmd} #{@fqdn} #{args}"
      logger.debug "running #{ipa_cmd}"
      @output = `#{ipa_cmd} 2>&1`
      if @output.empty? or @output =~ /Error/i
        logger.debug "ipa: errors\n" + @output.to_s
        if @output =~ /Insufficient access/i
          raise Proxy::Realm::KerberosError.new(@output.to_s)
        else
          raise Proxy::Realm::Error.new(@output.to_s)
        end
      end

      logger.debug "ipa: output\n" + @output.to_s
      #output.to_json

    end

    private

#    def init_krb5_ccache
#        logger.info "Requesting IPA credentials for Kerberos principal #{tsig_principal} using keytab #{tsig_keytab}"
#      begin
#        ccache = Kerberos::Krb5::CredentialsCache.new
#      rescue => e
#        logger.error "IPA Failed to create new Kerberos::Krb5::CredentialsCache:  #{e}"
#        raise Proxy::Realm::KerberosError.new("Unable to initialise Kerberos: #{e}")
#      end  
#      begin
#        krb5 = Kerberos::Krb5.new
#      rescue => e
#        logger.error "IPA Failed to create new Kerberos::Krb5: #{e}"
#        raise Proxy::Realm::KerberosError.new("Unable to initialise Kerberos: #{e}")
#      end  
#      begin
#        krb5.get_init_creds_keytab tsig_principal, tsig_keytab, nil, ccache
#      rescue => e
#        logger.error "IPA Failed to initialise credential cache from keytab: #{e}"
#        raise Proxy::Realm::KerberosError.new("Unable to initialise Kerberos: #{e}")
#      end
#      logger.debug "Kerberos credential cache initialised with principal: #{ccache.primary_principal}"
#    end


    def find_ipa
      @ipa = which("ipa", "/usr/bin")
      unless File.exists?("#{@ipa}")
        logger.warn "unable to find ipa binary, maybe missing ipa-admintools package?"
        raise "unable to find ipa binary"
      end
    end

    # I would love to have "ipa host-add" generate the password, but can't
    # think of a way to do that without actually adding the host
    def mk_pwd
      (0...8).map{(65+rand(26)).chr}.join
    end
  
  end
end

# vim: ai ts=2 sts=2 et sw=2 ft=ruby
