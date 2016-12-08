require 'net-ldap'
require 'realm/client'
 
module Proxy::Realm
  class ActiveDirectory < Client
    include Proxy::Util

    ADCLI_PATH="/sbin/adcli"

    def initialize
      errors = []
      errors << "adcli not found in path #{ADCLI_PATH}" unless have_adcli_cmd
      errors << "ad_domain not set" unless Proxy::Realm::Plugin.settings.ad_domain
      errors << "ad_user not set" unless Proxy::Realm::Plugin.settings.ad_user
      errors << "ad_password not set" unless Proxy::Realm::Plugin.settings.ad_password
      errors << "ad_server_ip no set" unless Proxy::Realm::Plugin.settings.ad_server_ip
      errors << "ad_server_port not set" unless Proxy::Realm::Plugin.settings.ad_server_port

      logger.debug "Proxy::Realm::ActiveDirectory:initialize"

      if errors.empty?
        @ad_domain = Proxy::Realm::Plugin.settings.ad_domain
        @ad_user = Proxy::Realm::Plugin.settings.ad_user
        @ad_password = Proxy::Realm::Plugin.settings.ad_password
        @ad_server_ip = Proxy::Realm::Plugin.settings.ad_server_ip
        @ad_server_port = Proxy::Realm::Plugin.settings.ad_server_port

        logger.debug "Loaded realm settings: ad_domain: #{@ad_domain}, ad_user: #{@ad_user}, ad_password: #{@ad_password}, ad_server_ip: #{@ad_server_ip}, ad_server_port: #{@ad_server_port}"
      else
        raise Proxy::Realm::Error.new errors.join(", ")
      end
    end

   def check_realm realm
     raise Proxy::Realm::Error.new "Unknown realm #{ad_domain}" unless realm.casecmp(@ad_domain).zero?
   end
 
   def have_adcli_cmd
       return File.exists? ADCLI_PATH || false
   end

   def find hostname
     return ldap_find_host hostname
   end

   def shortname hostname
     got_dots = check_dots hostname
     if got_dots 
       return hostname.split(".")[0]
     end
   end

   def check_dots hostname
     count=hostname.split(".").length
     if count > 1
       logger.debug "Probably FQDN"
       return true
     end
     logger.error "Unexpected hostname. Need FQDN: #{hostname}"
     return false
   end

   def create realm, params
     logger.debug "Proxy::Realm::ActiveDirectory:create #{realm} #{params}"
     
     hostname = params[:hostname]
     if check_dots hostname 
       logger.debug "Got dots..."
     else
       logger.error "Expected a FQDN, got #{params[:hostname]}"
       result = { "result" => { "message" => "nothing to do"}}
       return JSON.pretty_generate(result["result"])
     end

     found_host = find params[:hostname]

     logger.debug "ldap_find #{hostname} returned #{found_host}"   
 
     if found_host == false
       operation = "host_add"
     elsif found_host == true
       
       if params[:rebuild] == "true"
         logger.debug "rebuild = true"
         operation = "host_mod"
       else
         result = { "result" => { "message" => "nothing to do"}}
       end
     else
       result = { "result" => { "message" => "nothing to do"}}
     end

     logger.debug "operation: #{operation}"

     if operation == "host_add"
       
       otp_length=12
       otp=generate_password otp_length
       cmdline = create_preset_cmdline hostname, otp

       logger.debug "adcli preset-computer for host #{hostname}. Cmdline = #{cmdline}"
       system cmdline
       result = {"result" => {"randompassword" => otp}}
     elsif operation == "host_mod"

       otp_length=12
       otp=generate_password otp_length
       cmdline = create_reset_cmdline hostname, otp     
       
       logger.debug "adcli reset-computer for host #{hostname}. Cmdline = #{cmdline}"
       system cmdline
       default_adcli_pass = shortname hostname
       result = {"result" => {"randompassword" => default_adcli_pass }}
     else
       logger.debug "nothing to do. rebuild not selected."
       result = {"result" => {"message" => "nothing to do"}}
     end

     JSON.pretty_generate(result["result"])
   end

   def delete realm, hostname
     check_realm realm
     raise Proxy::Realm::NotFound, "Host #{hostname} not found in realm!" unless find hostname 
     cmdline = create_delete_cmdline hostname
     logger.debug "cmdline delete: #{cmdline}"
     result = {"result" => {"message" => "deleted host"}}
     JSON.pretty_generate(result)
   end

   def create_preset_cmdline hostname, otp
     cmd="echo -n "+@ad_password+" | #{ADCLI_PATH} preset-computer #{hostname} --one-time-password="+otp+" --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
     return cmd
   end

   def create_reset_cmdline hostname, otp
     cmd="echo -n "+@ad_password+" | #{ADCLI_PATH} reset-computer #{hostname} --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
     return cmd
   end

   def create_delete_cmdline hostname
     cmd="echo -n "+@ad_password+" | #{ADCLI_PATH} delete-computer #{hostname} --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
     return cmd
   end

   def domain_to_basedn domainname
     return "dc="+(domainname.split('.').join(',dc='))
   end

   def ldap_find_host hostname
     ldap = Net::LDAP.new
     ldap.host = @ad_server_ip 
     ldap.port = @ad_server_port
     ldap.auth @ad_user, @ad_password

     filter = Net::LDAP::Filter.eq( "DNSHostname", hostname )
     treebase = domain_to_basedn @ad_domain

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

   # https://github.com/freeipa/freeipa/blob/master/ipapython/ipautil.py
   def generate_password(pwd_len)
       ascii_letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
       digits = '0123456789'
       #punctuation = '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'
       #characters = (digits + ascii_letters + punctuation + ' ')
       characters = (digits + ascii_letters + ' ')
       if pwd_len.nil?
           pwd_len=22
       end
       upper_bound = characters.length - 1
       rndpwd = ''
       r = Random.new
       for i in (0..pwd_len) do
           rnd_i = Integer(r.rand(0..upper_bound))
           rnd_char = characters[rnd_i]
           if ( (rnd_i == 0) || (rnd_i == pwd_len-1) )
               while (rnd_char == ' ') do 
                   print "oops got blank..."
                   rnd_char = characters[Integer(r.rand(0..upper_bound))]
               end
           else
               rndpwd += rnd_char
           end
       end
       return rndpwd
   end
  end
end

