module Proxy::Puppet
  class Mcollective
    extend Proxy::Util

    def self.run(nodes)
      mco_search_path = ["/usr/bin", "/opt/puppet/bin"]
      sudo = which("sudo", "usr/bin")

      mco = which("mco", mco_search_path)

      unless sudo and mco
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      mco << " puppet runonce -I #{nodes}"

      begin
        %x[#{sudo} #{mco}]
        true
      rescue
        false
      end
    end
  end

  class PuppetRun
    extend Proxy::Util

    def self.run(nodes)
      # Search in /opt/ for puppet enterprise users
      default_path = ["/usr/sbin", "/usr/bin", "/opt/puppet/bin"]
      # search for puppet for users using puppet 2.6+
      puppetrun    = which("puppetrun", default_path) || which("puppet", default_path)
      sudo         = which("sudo", "/usr/bin")

      unless puppetrun and sudo
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
      end

      # Append kick to the puppet command if we are not using the old puppetca command
      puppetrun << " kick" unless puppetrun.include?('puppetrun')

      command = %x[#{sudo} #{puppetrun} --host #{nodes.join(" --host ")}]
      unless command =~ /finished with exit code 0/
        logger.warn command
        return false
      end
      return true
    end
  end
end
