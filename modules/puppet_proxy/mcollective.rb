require 'puppet_proxy/runner'

class Proxy::Puppet::MCollective < Proxy::Puppet::Runner
  def run
    cmd = []
    cmd.push(which("sudo"))

    # whatever user this is getting the sudo permissions will need to be added to ensure the smart-proxy
    # can execute the sudo command
    # For Puppet Enterprise this means
    # Defaults:foreman-proxy !requiretty
    # foreman-proxy ALL=(peadmin) NOPASSWD: /opt/puppet/bin/mco *',
    user = Proxy::Puppet::Plugin.settings.mcollective_user || Proxy::Puppet::Plugin.settings.puppet_user
    if user
      cmd.push("-u", user)
    end

    cmd.push(which("mco", "/opt/puppet/bin"))

    if cmd.include?(false)
      logger.warn "sudo or the mco binary is missing."
      logger.warn "You must have the correct sudo permissions like: foreman-proxy ALL=(${user}) NOPASSWD: /opt/puppet/bin/mco *'" if user
      return false
    end

    shell_command(cmd + ["puppet", "runonce", "-I"] + shell_escaped_nodes)
  end
end
