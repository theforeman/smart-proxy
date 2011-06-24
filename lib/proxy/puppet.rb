module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util

  class << self
    def run *hosts
      # Search in /opt/ for puppet enterprise users
      default_path = ["/usr/sbin", "/usr/bin", "/opt/puppet/bin"]
      # search for puppet for users using puppet 2.6+
      puppetrun = which("puppetrun", default_path) || which("puppet", default_path)
      sudo = which("sudo", "/usr/bin")

      unless puppetrun and sudo
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
      end
      # Append kick to the puppet command if we are not using the old puppetca command
      if not puppetrun.include? 'puppetrun'
        puppetrun << " kick"
      end
      command = %x[#{sudo} #{puppetrun} --host #{hosts.join(" --host ")}]
      if command =~ /finished with exit code 0/
        return true
      else
        logger.warn command
        return false
      end
    end
  end
end
