require 'net-ldap'
require 'proxy/kerberos'

module Proxy::ADRealm
  class Provider
    include Proxy::Log
    include Proxy::Util
    include Proxy::Kerberos

    def initialize(realm, keytab_path, principal, domain_controller, ldap_user, ldap_password)
      @realm = realm
      @keytab_path = keytab_path
      @principal = principal
      @domain_controller = domain_controller
      @ldap_user = ldap_user
      @ldap_password = ldap_password
      @ldap_port = ldap_port

      # Get krb5 token
      init_krb5_ccache @keytab_path, @principal
    end

    def check_realm realm
    end

    def find hostname
      
    end

    def create realm, hostname, params
      check_realm realm
    end

    def do_host_rebuild(hostname)
    end

    def do_host_modify(hostname)
    end

    def do_host_create(hostname)
    end

    def delete realm, hostname
      check_realm realm
    end

    private

    # def ldap_host_exists? hostname
    #   ldap = Net::LDAP.new
    #   ldap.host = @domain_controller 
    #   ldap.port = @ldap_port
    #   ldap.auth @ldap_user, @ldap_password

    #   filter = Net::LDAP::Filter.eq( "DNSHostname", hostname )
    #   treebase = domainname_to_basedn @ad_domain

    #   if ldap.bind 

    #     ldap.search( :base => treebase, :filter => filter) do |entry|
    #       if entry == nil
    #         logger.debug "Host with DNSName #{hostname} was not found in domain"
    #         return false
    #       else 
    #         logger.debug "Found Host in domain for DNSName #{hostname}"         
    #         logger.debug "LDAP Returned DN: #{entry.dn}"
    #         return true
    #       end
    #     end
    #   else
    #     logger.debug "Authentication failed"
    #     ldap.get_operation_result
    #     return false
    #   end
    #   return false 
    # end 

    def radcli_join computer_name, password
    end

    def radcli_reset computer_name, newpassword
    def

    def radcli_delete computer_name
    end
  end
end
