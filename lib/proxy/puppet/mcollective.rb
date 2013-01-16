require 'proxy/puppet'

module Proxy::Puppet
  class MCollective < Runner
    def run
      mco_search_path = ["/usr/bin", "/opt/puppet/bin"]
      sudo = which("sudo", "/usr/bin")

      mco = which("mco", mco_search_path)

      unless sudo and mco
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      mco << " puppet runonce -I #{nodes.join(' ')}"

      begin
        %x[#{sudo} #{mco}]
        true
      rescue
        false
      end
    end
  end
end
