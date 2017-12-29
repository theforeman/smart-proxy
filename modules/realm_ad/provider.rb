require 'proxy/kerberos'
require 'radcli'
require 'digest'

module Proxy::AdRealm
  class Provider
    include Proxy::Log
    include Proxy::Util
    include Proxy::Kerberos

    attr_reader :realm, :keytab_path, :principal, :domain_controller, :domain, :ou, :computername_prefix, :computername_hash, :computername_use_fqdn

    def initialize(options = {})
      @realm = options[:realm]
      @keytab_path = options[:keytab_path]
      @principal = options[:principal]
      @domain_controller = options[:domain_controller]
      @domain = options[:realm].downcase
      @ou = options[:ou]
      @computername_prefix = options[:computername_prefix]
      @computername_hash = options[:computername_hash]
      @computername_use_fqdn = options[:computername_use_fqdn]
      logger.info 'Proxy::AdRealm: initialize...'
    end

    def check_realm(realm)
      raise Exception, "Unknown realm #{realm}" unless realm.casecmp(@realm).zero?
    end

    def find(_hostfqdn)
      true
    end

    def create(realm, hostfqdn, params)
      logger.info "Proxy::AdRealm: create... #{realm}, #{hostfqdn}, #{params}"
      check_realm(realm)
      kinit_radcli_connect

      password = generate_password
      result = { randompassword: password }

      computername = hostfqdn_to_computername(hostfqdn)

      if params[:rebuild] == 'true'
        radcli_password(computername, password)
      else
        radcli_join(hostfqdn, computername, password)
      end

      JSON.pretty_generate(result)
    end

    def delete(realm, hostfqdn)
      logger.info "Proxy::AdRealm: delete... #{realm}, #{hostfqdn}"
      kinit_radcli_connect
      check_realm(realm)
      computername = hostfqdn_to_computername(hostfqdn)
      radcli_delete(computername)
    end

    private

    def hostfqdn_to_computername(hostfqdn)
      computername = hostfqdn

      # strip the domain from the host
      computername = computername.split('.').first unless computername_use_fqdn

      # generate the SHA256 hexdigest from the computername
      computername = Digest::SHA256.hexdigest(computername) if computername_hash

      # apply prefix if it has not already been applied
      computername = computername_prefix + computername if apply_computername_prefix?(computername)

      # limit length to 15 characters and upcase the computername
      # see https://support.microsoft.com/en-us/kb/909264
      computername[0, 15].upcase
    end

    def apply_computername_prefix?(computername)
      !computername_prefix.nil? && !computername_prefix.empty? && (computername_hash || !computername[0, computername_prefix.size].casecmp(computername_prefix).zero?)
    end

    def kinit_radcli_connect
      init_krb5_ccache(@keytab_path, @principal)
      @adconn = radcli_connect
    end

    def radcli_connect
      # Connect to active directory
      conn = Adcli::AdConn.new(@domain)
      conn.set_domain_realm(@realm)
      conn.set_domain_controller(@domain_controller)
      conn.set_login_ccache_name('')
      conn.connect
      conn
    end

    def radcli_join(hostfqdn, computername, password)
      # Join computer
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computername)
      enroll.set_host_fqdn(hostfqdn)
      enroll.set_domain_ou(@ou) if @ou
      enroll.set_computer_password(password)
      enroll.join
    end

    def generate_password
      characters = ('A'..'Z').to_a + ('a'..'z').to_a + (0..9).to_a
      Array.new(20) { characters.sample }.join
    end

    def radcli_password(computername, password)
      # Reset a computer's password
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computername)
      enroll.set_domain_ou(@ou) if @ou
      enroll.set_computer_password(password)
      enroll.password
    end

    def radcli_delete(computername)
      # Delete a computer's account
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computername)
      enroll.set_domain_ou(@ou) if @ou
      enroll.delete
    end
  end
end
