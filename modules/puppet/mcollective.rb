require 'puppet/runner'

class Proxy::Puppet::MCollective < Proxy::Puppet::Runner
  def run
    cmd = []
    cmd.push(which("sudo"))

    if Proxy::Puppet::Plugin.settings.puppet_user
      cmd.push("-u", Proxy::Puppet::Plugin.settings.puppet_user)
    end

    cmd.push(which("mco", "/opt/puppet/bin"))

    if cmd.include?(false)
      logger.warn "sudo or the mco binary is missing."
      return false
    end

    shell_command(cmd + ["puppet", "runonce", "-I"] + shell_escaped_nodes)
  end
end
