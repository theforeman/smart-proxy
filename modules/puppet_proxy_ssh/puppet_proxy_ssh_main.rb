class Proxy::PuppetSsh::Runner < Proxy::Puppet::Runner
  attr_reader :command, :user, :keyfile_path, :use_sudo, :wait_for_command_to_finish

  def initialize(puppetssh_command, puppetssh_user, ssh_keyfile, use_sudo, wait_for_command_to_finish)
    @command = puppetssh_command
    @user = puppetssh_user
    @keyfile_path = ssh_keyfile.to_s
    @use_sudo = use_sudo
    @wait_for_command_to_finish = wait_for_command_to_finish
  end

  def run(nodes)
    cmd = []

    if use_sudo
      sudo_path = which('sudo')
      unless sudo_path
        logger.error('sudo binary is missing, aborting.')
        return false
      end
      cmd.push(sudo_path)
    end

    ssh_path = which('ssh')
    unless ssh_path
      logger.error('ssh binary is missing, aborting.')
      return false
    end
    cmd.push(ssh_path)

    cmd.push('-o', 'StrictHostKeyChecking=no')
    cmd.push("-l", user) if user

    if keyfile_path
      if File.exist?(keyfile_path)
        cmd.push("-i", keyfile_path)
      else
        logger.warn("Unable to access SSH private key:#{keyfile_path}, ignoring...")
      end
    end

    nodes.each do |node|
      shell_command(cmd + [escape_for_shell(node), command], wait_for_command_to_finish)
    end
  end
end
