class Proxy::PuppetSalt::Runner < Proxy::Puppet::Runner
  attr_reader :command

  def initialize(puppetrun_command)
    @command = puppetrun_command
  end

  def run(nodes)
    cmd = []

    sudo_path = which('sudo')
    unless sudo_path
      logger.error('sudo binary is missing, aborting.')
      return false
    end
    cmd.push(sudo_path)

    salt_path = which('salt')
    unless sudo_path
      logger.error('salt binary is missing, aborting.')
      return false
    end
    cmd.push(salt_path)

    cmd.push('-L')
    cmd.push(shell_escaped_nodes(nodes).join(','))
    cmd.push(command)

    shell_command(cmd)
  end
end
