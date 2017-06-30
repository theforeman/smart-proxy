require 'net-ldap'
require 'realm/client'

module Proxy::Realm
  class ActiveDirectory < Client
    include Proxy::Util

    PWD_LEN=12
    ADCLI_PATH="/sbin/adcli"

    def initialize
      errors = []
      errors << "adcli not found in path #{ADCLI_PATH}" unless have_adcli_cmd?
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

  def check_host_found hostname
      log_halt 404, "Host #{hostname} was not found in realm!" unless ldap_host_exists? hostname
  end

  def check_host_notfound hostname
      log_halt 400, "Unexpected! Host #{hostname} was found in realm!" unless host_exists? hostname == false
  end

  def check_hostname_fqdn hostname
      log_halt 400, "Host #{hostname} is not in FQDN form!" unless hostname_fqdn? hostname 
  end
 
  def is_rebuild_selected? params
    if params[:rebuild] == "true"
      return true
    else
      return false
    end
  end

  def have_adcli_cmd?
    return File.exists? ADCLI_PATH || false
  end
 
  def fqdn_to_shortname hostname
    got_dots = check_dots hostname
    if got_dots 
      return hostname.split(".")[0]
    end
  end

  def hostname_fqdn? hostname
    count=hostname.split(".").length
    if count > 1
      logger.debug "Probably FQDN"
      return true
    end
    logger.error "Unexpected hostname. Need FQDN: #{hostname}"
    return false
  end

  def create realm, params
    check_realm realm
    check_hostname_fqdn params[:hostname]

    logger.debug "Proxy::Realm::ActiveDirectory:create #{realm} #{params}"
    host_found = ldap_host_exist? params[:hostname]

    # Guard against existing host but missing rebuild option
    log_halt 404, "Hosts exists but rebuild was not set" unless host_found && (is_rebuild_selected? == false)

    if host_found && is_rebuild_selected?
      operation = "rebuild"
    else 
      operation = "create"
    end
 
    if operation == "create"
      otp_password = generate_password PWD_LEN
      adcli_preset hostname otp_password
      logger.debug "adcli preset-computer for host #{hostname}. otp_password = #{otp_password}"
      result = {"result" => {"randompassword" => otp_password}}
    elsif operation == "rebuild"
      logger.debug "adcli reset-computer for host #{hostname}."
      adcli_reset hostname
      default_pass = fqdn_to_shortname hostname
      result = {"result" => {"randompassword" => default_pass }}
      JSON.pretty_generate(result["result"])
    else
      log_halt 404, "Unexpected operation!" 
    end

    log_halt 404, "Should not see this...!" 
  end

  def delete realm, hostname
    check_realm realm
    check_hostname_fqdn params[:hostname]
    check_host_exists hostname

    cmdline = create_delete_cmdline hostname
    logger.debug "cmdline delete: #{cmdline}"

    result = {"result" => {"message" => "deleted host"}}
    JSON.pretty_generate(result)
  end

  def adcli_preset hostname, otp
    cmd = "echo -n "+@ad_password+" | #{ADCLI_PATH} preset-computer #{hostname} --one-time-password="+otp+" --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
    shell_command(escape_for_shell(cmd), true)
  end

  def adcli_reset hostname
    cmd = "echo -n "+@ad_password+" | #{ADCLI_PATH} reset-computer #{hostname} --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
    shell_command(escape_for_shell(cmd), true)
  end

  def adcli_delete hostname, otp
    cmd="echo -n "+@ad_password+" | #{ADCLI_PATH} delete-computer #{hostname} --domain=#{@ad_domain} -U #{@ad_user} --stdin-password"
    shell_command(escape_for_shell(cmd), true)
  end

  def domainname_to_basedn domainname
    return "dc="+(domainname.split('.').join(',dc='))
  end

  def ldap_host_exists? hostname
    ldap = Net::LDAP.new
    ldap.host = @ad_server_ip 
    ldap.port = @ad_server_port
    ldap.auth @ad_user, @ad_password

    filter = Net::LDAP::Filter.eq( "DNSHostname", hostname )
    treebase = domainname_to_basedn @ad_domain

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

