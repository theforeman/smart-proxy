require 'puppet_proxy/runner'

class Proxy::Puppet::Salt < Proxy::Puppet::Runner
  def run
    cmd = []
    cmd.push(which('sudo'))
    cmd.push(which('salt'))

    if cmd.include?(false)
      logger.warn 'sudo or the salt binary is missing.'
      return false
    end

    cmd.push('-L')
    cmd.push(shell_escaped_nodes.join(','))
    salt_puppetrun_cmd = Proxy::Puppet::Plugin.settings.salt_puppetrun_cmd
    cmd.push(salt_puppetrun_cmd)

    shell_command(cmd)
  end
end
