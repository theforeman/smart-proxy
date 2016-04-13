module Proxy::PuppetRun
  class Runner < ::Proxy::Puppet::Runner
    attr_reader :user

    def initialize(puppetrun_user)
      @user = puppetrun_user
    end

    def run(nodes)
      cmd = []

      sudo_path = which("sudo")
      unless sudo_path
        logger.error("sudo binary is missing, aborting.")
        return false
      end
      cmd.push(sudo_path)

      if user
        cmd.push("-u", user)
      end

      default_path = "/opt/puppet/bin"
      # Search in /opt/ for puppet enterprise users
      # search for puppet for users using puppet 2.6+
      puppetrun_path = which("puppetrun", default_path) || which("puppet", default_path)
      unless puppetrun_path
        logger.error("puppetrun binary was not found - aborting.")
        return false
      end
      cmd.push(puppetrun_path)

      # Append kick to the puppet command if we are not using the old puppetca command
      cmd.push("kick") if cmd.any? { |part| part.end_with?('puppet') }
      shell_command(cmd + (shell_escaped_nodes(nodes).map {|n| ["--host", n] }).flatten)
    end
  end
end
