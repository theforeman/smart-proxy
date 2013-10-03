require 'proxy/puppet'

module Proxy::Puppet
  class MCollective < Runner
    def run
      cmd = []
      cmd.push(which("sudo", "/usr/bin"))

      if SETTINGS.puppet_mco_user
        cmd.push("-u",SETTINGS.puppet_mco_user)
      end

      cmd.push(which("mco", ["/usr/bin", "/opt/puppet/bin"]))

      if cmd.include?(false)
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      shell_command(cmd + ["puppet", "runonce", "-I"] + shell_escaped_nodes)
    end
  end
end
