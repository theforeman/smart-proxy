require 'proxy/puppet'

module Proxy::Puppet
  class Salt < Runner
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
      cmd.push('puppet.run')

      shell_command(cmd)
    end
  end
end
