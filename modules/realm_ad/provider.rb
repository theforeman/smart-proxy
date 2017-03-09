require 'proxy/kerberos'
require 'net-ldap'
require 'radcli'

module Proxy::ADRealm
  class Provider
    include Proxy::Log
    include Proxy::Util
    include Proxy::Kerberos

    def initialize(realm, keytab_path, principal, domain_controller)
      @realm = realm
      @keytab_path = keytab_path
      @principal = principal
      @domain_controller = domain_controller
      @realm = realm
      @domain = realm.downcase
    end

    def check_realm realm
      raise Exception.new "Unknown realm #{realm}" unless realm.casecmp(@realm).zero?
    end

    def find hostname
      true
    end

    def create realm, hostname, params
      check_realm realm
      kinit_radcli_connect
      password = generate_password
      result = { :randompassword => password }
      begin
        if params[:rebuild] == "true"
          do_host_rebuild hostname, password
        else
          do_host_create hostname, password
        end
      rescue 
        raise
      end 
      JSON.pretty_generate(result)
    end
 
    def delete realm, hostname
      kinit_radcli_connect()
      check_realm realm
      begin
        radcli_delete hostname
      rescue Adcli::AdEnroll::Exception =>
        raise
      end
    end

    def generate_password
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
   
    def do_host_create hostname, password
      computername = hostfqdn_hostname hostname
      radcli_join(computername, hostname, password)
    end

    def do_host_rebuild hostname, password
      computername = hostfqdn_hostname hostname
      radcli_password(computername, password)
    end
    
    def kinit_radcli_connect
      init_krb5_ccache @keytab_path, @principal
      @adconn = radcli_connect()
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
  end
end
