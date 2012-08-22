module Proxy::Squid
  extend Proxy::Log
  extend Proxy::Util

  require "proxy/settings"

  class << self
    def reconfigure *host
      path  = ['/usr/sbin', '/usr/bin', '/opt/squid3/bin', '/opt/squid/bin']
      squid = which('squid3', path) || which('squid', path)
      sudo  = which('sudo', '/usr/bin')

      unless squid and sudo
        logger.warn 'sudo or squid binary was not found - aborting'
        return false
      end

      parse_output = %x[#{sudo} #{squid} -k parse]
      if $? != 0
        logger.warn parse_output
        return false
      end

      restart_output = %x[#{sudo} #{squid} -k reconfigure]
      if $? != 0
        logger.warn restart_output
        return false
      end

      return true
    end

    def add *hosts
      hosts.each do |ip_addr|
        filename = File.join(SETTINGS.squid_conf_dir, 'foreman.d', "#{ip_addr}.conf")
        File.open( filename, 'w' ) do |f|
          f.puts "acl foreman_clients src #{ip_addr}"
        end
      end
      reconfigure
    end

    def rm *hosts
      hosts.each do |ip_addr|
        filename = File.join(SETTINGS.squid_conf_dir, 'foreman.d', "#{ip_addr}.conf")
        File.unlink( filename )
      end
      reconfigure
    end
  end
end
