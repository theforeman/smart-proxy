class Proxy::PuppetMCollective::Runner < Proxy::Puppet::Runner
  attr_reader :user

  def initialize(mco_user)
    @user = mco_user
  end

  def run(nodes)
    cmd = []

    sudo_path = which('sudo')
    unless sudo_path
      logger.error("sudo binary is missing, aborting.")
      return false
    end
    cmd.push(sudo_path)

    # sudo permission needs to be added to ensure
    # smart-proxy can execute 'sudo' command
    # For Puppet Enterprise this means
    # Defaults:foreman-proxy !requiretty
    # foreman-proxy ALL=(peadmin) NOPASSWD: /opt/puppet/bin/mco *',
    if user
      cmd.push("-u", user)
    end

    mco_path = which("mco", ["/opt/puppet/bin", "/opt/puppetlabs/bin"])
    unless mco_path
      logger.error("mco binary is missing, aborting.")
      return false
    end
    cmd.push(mco_path)

    shell_command(cmd + ["puppet", "runonce", "-I"] + shell_escaped_nodes(nodes))
  end
end
