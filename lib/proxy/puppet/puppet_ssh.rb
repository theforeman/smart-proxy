require 'proxy/puppet'

module Proxy::Puppet
  class PuppetSSH < Runner
    def run
      cmd = []
      cmd.push(which('sudo')) if SETTINGS.puppetssh_sudo
      cmd.push(which('ssh'))
      cmd.push("-l#{SETTINGS.puppetssh_user}") if SETTINGS.puppetssh_user
      if (file = SETTINGS.puppetssh_keyfile)
        if File.exists?(file)
          cmd.push("-i#{file}")
        else
          logger.warn("Unable to access SSH private key:#{file}, ignoring...")
        end
      end

      if cmd.include?(false)
        logger.warn 'sudo or the ssh binary is missing.'
        return false
      end

      ssh_command = escape_for_shell(SETTINGS.puppetssh_command || 'puppet agent --onetime --no-usecacheonfailure')
      nodes.each do |node|
        shell_command(cmd + [escape_for_shell(node), ssh_command], false)
      end
    end
  end
end
