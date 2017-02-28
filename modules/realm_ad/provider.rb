require 'proxy/kerberos'
require 'radcli'

module Proxy::ADRealm
  class Provider
    include Proxy::Log
    include Proxy::Util
    include Proxy::Kerberos

    def initialize(realm, keytab_path, principal, domain_controller, ldap_user, ldap_password, ldap_port)
      @realm = realm
      @keytab_path = keytab_path
      @principal = principal
      @domain_controller = domain_controller
      @ldap_user = ldap_user
      @ldap_password = ldap_password
      @ldap_port = ldap_port
      @domain = @realm.downcase

      # Connec to active directory
      init_krb5_ccache @keytab_path, @principal
      @adconn = radcli_connect
    end

    def check_realm realm
      raise Exception.new "Unknown realm #{realm}" unless realm.casecmp(@realm).zero?
    end

    def find hostname
      ldap_host_exists? hostname
    end

    def create realm, hostname, params
      check_realm realm
      begin
        if params[:rebuild] == "true"
          otp = generate_random_password()
          radcli_reset(@adconn, otp)
          result = {:randompassword => otp}
        else
          otp = generate_random_password()
          radcli_password(@adconn, otp)
          result = {:randompassword => otp}
        end
      rescue AdEnroll::Exception  => e
        raise
      end
    end
 
    def delete realm, hostname
      check_realm realm
      begin
        radcli_delete(@adconn, hostname)
      rescue AdEnroll::Exception =>
        raise
      end
    end

    def generate_random_password
      return "_i7@PhgpAnjn"
    end

    private

    def radcli_connect 
      # Connect to active directory
      conn = Adcli::AdConn.new(@domain)
      conn.set_domain_realm(@realm)
      conn.set_domain_controller(@domain_controller)
      conn.set_login_ccache_name("")
      conn.connect()
      return conn
    end

    def radcli_join computer_name, password
      # Join computer
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computer_name)
      enroll.set_computer_password(password)
      enroll.join()
    end

    def radcli_password computer_name
      # Reset a computer's password
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computer_name)
      enroll.set_computer_name(computer_name)
      enroll.password()
    end

    def radcli_delete computer_name
      # Delete a computer's account
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computer_name)
      enroll.delete()
    end  

    def domainname_to_basedn domainname		
      return "dc="+(domainname.split('.').join(',dc='))		
    end

    def ldap_host_exists? hostname		
      ldap = Net::LDAP.new		
      ldap.host = @domain_controller 		
      ldap.port = @ldap_port		 
      ldap.auth @ldap_user, @ldap_password		
      filter = Net::LDAP::Filter.eq( "DNSHostname", hostname )		
      treebase = domainname_to_basedn @realm		
      if ldap.bind 		
        ldap.search( :base => treebase, :filter => filter) do |entry|		
          if entry == nil		
            logger.debug "ldap_host_exists: host with dnsname #{hostname} was not found in domain"		
            return false		
          else 		
            logger.debug "ldap_host_exists: found host in domain for DNSName #{hostname}"         		
            logger.debug "ldap_host_exists: ldap returned dn: #{entry.dn}"		
            return true		
          end		
        end		
      else		
        logger.debug "Authentication failed"		
        ldap.get_operation_result		
        return false		
      end		
      return false 		
    end 

  end
end
