require 'puppet_proxy/runner'

class Proxy::Puppet::PuppetSSH < Proxy::Puppet::Runner
  def run
    cmd = []
    cmd.push(which('sudo')) if Proxy::Puppet::Plugin.settings.puppetssh_sudo
    cmd.push(which('ssh'))
    cmd.push("-l", "#{Proxy::Puppet::Plugin.settings.puppetssh_user}") if Proxy::Puppet::Plugin.settings.puppetssh_user
    if (file = Proxy::Puppet::Plugin.settings.puppetssh_keyfile)
      if File.exists?(file)
        cmd.push("-i", "#{file}")
      else
        logger.warn("Unable to access SSH private key:#{file}, ignoring...")
      end
    end

    if cmd.include?(false)
      logger.warn 'sudo or the ssh binary is missing.'
      return false
    end

    ssh_command = escape_for_shell(Proxy::Puppet::Plugin.settings.puppetssh_command || 'puppet agent --onetime --no-usecacheonfailure')
    nodes.each do |node|
      shell_command(cmd + [escape_for_shell(node), ssh_command], Proxy::Puppet::Plugin.settings.puppetssh_wait || false)
    end
  end
end
