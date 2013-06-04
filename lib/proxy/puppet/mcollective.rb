require 'proxy/puppet'

module Proxy::Puppet
  class MCollective < Runner
    def run
      sudo = which("sudo", "/usr/bin")
      logger.debug "Found sudo at #{sudo}"

      mco_search_path = ["/usr/bin", "/opt/puppet/bin"]
      mco = which("mco", mco_search_path)
      logger.debug "Found mco at #{mco}"

      unless sudo and mco
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      mco << " puppet runonce -I #{nodes.join(' ')}"

      begin
        logger.debug "Executing #{sudo} #{mco}"
        %x[#{sudo} #{mco}]
        true
      rescue
        false
      end
    end
  end
end
