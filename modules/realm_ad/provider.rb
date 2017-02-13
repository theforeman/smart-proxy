require 'net-ldap'
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

      # Get krb5 token
      init_krb5_ccache @keytab_path, @principal
    end

    def check_realm realm
      raise Exception.new "Unkown realm #{realm}" unless realm.casecmp(@realm).zero?
    end

    def find hostname
      ldap_host_exists? hostname
    end
    
    def create realm, hostname, params
      puts "realm: #{realm}"
      check_realm realm
      
      exists = find hostname
      logger.info "hostname: #{hostname}, exists: #{exists}"
      logger.info params

      if !exists
        logger.info "host create: #{hostname}"
        result = do_host_create(hostname)
      elsif params[:rebuild] == "true"
        logger.info "host rebuild: #{hostname}"
        result = do_host_rebuild(hostname)
      else
        logger.info "Nothing to do" 
      end

    end

    def do_host_rebuild(hostname)
      logger.info "do_host_create: #{hostname}"
      adconn = radcli_connect(@realm, @domain_controller)
      enroll = Adcli::AdEnroll.new(adconn)
      puts adconn
      puts enroll
      enroll.set_computer_name(hostname)
      enroll.set_computer_password("newpass")
      enroll.password()
    end

    def do_host_modify(hostname)
    end

    def do_host_create(hostname)
      logger.info "do_host_create: #{hostname}"
      adconn = radcli_connect(@realm, @domain_controller)
      puts adconn

      enroll = Adcli::AdEnroll.new(adconn)
      puts enroll

      enroll.set_computer_name(hostname)
      enroll.set_computer_password("password")
      enroll.join
    end

    def delete realm, hostname
      check_realm realm
      logger.info "do_host_create: #{hostname}"
      adconn = radcli_connect(@realm, @domain_controller)
      enroll = Adcli::AdEnroll.new(adconn)
      enroll.set_computer_name(hostname)
      enroll.delete()
    end

    private

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
            logger.debug "Host with DNSName #{hostname} was not found in domain"
            return false
          else 
            logger.debug "Found Host in domain for DNSName #{hostname}"         
            logger.debug "LDAP Returned DN: #{entry.dn}"
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

    def radcli_connect realm, domain_controller
      domain_name = realm.downcase
      adconn = Adcli::AdConn.new(domain_name)
      adconn.set_domain_realm(realm)
      adconn.set_domain_controller(domain_controller)
      adconn.set_login_ccache_name("")
      res = adconn.connect
      adconn
    end
  end
end
