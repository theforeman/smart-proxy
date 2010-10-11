module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util

  class << self
    def run *hosts
      puppetrun = which("puppetrun", ["/usr/sbin", "/usr/bin"])
      sudo = which("sudo", "/usr/bin")

      unless puppetrun and sudo
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
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
