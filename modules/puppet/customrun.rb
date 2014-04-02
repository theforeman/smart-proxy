require 'puppet/runner'

class Proxy::Puppet::CustomRun < Proxy::Puppet::Runner
  def run
    cmd = Proxy::Puppet::Plugin.settings.customrun_cmd
    unless File.exists?( cmd )
      logger.warn "#{cmd} not found."
      return false
    end

    shell_command( [ escape_for_shell(cmd), Proxy::Puppet::Plugin.settings.customrun_args, shell_escaped_nodes ] )
  end
end
