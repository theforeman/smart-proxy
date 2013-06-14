require 'proxy/puppet'

module Proxy::Puppet
  class PuppetRun < Runner
    def run
      # Search in /opt/ for puppet enterprise users
      default_path = ["/usr/sbin", "/usr/bin", "/opt/puppet/bin"]
      # search for puppet for users using puppet 2.6+
      cmd = []
      cmd.push(which("sudo", "/usr/bin"))
      cmd.push(which("puppetrun", default_path) || which("puppet", default_path))

      if cmd.include?(false)
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
      end

      # Append kick to the puppet command if we are not using the old puppetca command
      cmd.push("kick") if cmd.any? { |part| part.end_with?('puppet') }
      shell_command(cmd + (shell_escaped_nodes.map {|n| ["--host", n] }).flatten)
    end
  end
end
