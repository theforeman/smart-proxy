require 'proxy/puppet'

module Proxy::Puppet
  class MCollective < Runner
    def run
      cmd = []
      unless ENV['USER'] == SETTINGS.puppet_user
        cmd.push(which("sudo"))

        if SETTINGS.puppet_user
          cmd.push("-u", SETTINGS.puppet_user)
        end
      end

      cmd.push(which("mco", "/opt/puppet/bin"))

      if cmd.include?(false)
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      shell_command(cmd + ["puppet", "runonce", "-I"] + shell_escaped_nodes)
    end
  end
end
