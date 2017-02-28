require 'proxy/kerberos'
require 'net-ldap'
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
      cn = hostfqdn_hostname hostname
      if ldap_host_exists? cn
        hostname
      else
        nil        
      end
    end

    def create realm, hostname, params
      check_realm realm
      logger.debug "params: #{params}"

      host = find(hostname)
      logger.debug "find: #{host}"
      if host.nil?
        logger.debug "host is nil: #{host}"
        result = do_host_create(hostname)
      elsif params[:rebuild] == "true"
        logger.debug "hos option rebuild is true"
        result = do_host_rebuild(hostname)
      else
        logger.debug "option rebuild is not true"
      end

      logger.debug "create end"
    end
 
    def delete realm, hostname
      check_realm realm
      begin
        radcli_delete hostname
      rescue Adcli::AdEnroll::Exception =>
        raise
      end
    end

    def generate_random_password
      return "_i7@PhgpAnjn"
    end

    private

    def hostfqdn_hostname host_fqdn
      begin
        host_fqdn_split = host_fqdn.split('.')
        host_fqdn_split[0]
      rescue  
        logger.debug "hostfqdn_hostname error"
        raise
      end
    end
   
    def do_host_create hostname
      otp = generate_random_password()
      computername = hostfqdn_hostname hostname
      radcli_join(computername, hostname, otp)
      result = {:randompassword => otp}
      result
    end

    def do_host_rebuild hostname
      otp = generate_random_password()
      computername = hostfqdn_hostname hostname
      radcli_password(computername, otp)
      result = {:randompassword => otp}
      result
    end

    def radcli_connect 
      # Connect to active directory
      conn = Adcli::AdConn.new(@domain)
      conn.set_domain_realm(@realm)
      conn.set_domain_controller(@domain_controller)
      conn.set_login_ccache_name("")
      conn.connect()
      return conn
    end

    def radcli_join computer_name, hostname, password
      # Join computer
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computer_name)
      enroll.set_host_fqdn(hostname)
      enroll.set_computer_password(password)
      enroll.join()
    end

    def radcli_password computer_name, password
      # Reset a computer's password
      enroll = Adcli::AdEnroll.new(@adconn)
      enroll.set_computer_name(computer_name)
      enroll.set_computer_password(password)
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
      ldap = Net::LDAP.new :host => @domain_controller,
        :port => @ldap_port,
        :auth => {
           :method => :simple,
           :username => @ldap_user,
           :password => @ldap_password
        }
      filter = Net::LDAP::Filter.eq( "cn", hostname )		
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
        logger.debug "ldap_host_exists: ldap bind failed"		
        logger.debug ldap.get_operation_result		
        return false		
      end		
      return false 		
    end 

  end
end
