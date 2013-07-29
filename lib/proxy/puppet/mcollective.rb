require 'proxy/puppet'

module Proxy::Puppet
  class MCollective < Runner
    def run
      cmd = []
      cmd.push(which("sudo", "/usr/bin") + " ")
      cmd.push(which("mco", ["/usr/bin", "/opt/puppet/bin"]) + " ")

      if cmd.include?(false)
        logger.warn "sudo or the mco binary is missing."
        return false
      end

      nodenames = []
      shell_escaped_nodes.each { |x|
        y = x.split('.')
        nodenames.push(y.first)
      }
      shell_command(cmd + ["puppet ", "runonce ", "-I ", nodenames, " "] + shell_escaped_nodes)
    end
  end
end
