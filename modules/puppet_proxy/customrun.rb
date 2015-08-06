require 'puppet_proxy/runner'

class Proxy::Puppet::CustomRun < Proxy::Puppet::Runner
  def run
    cmd = Proxy::Puppet::Plugin.settings.customrun_cmd
    unless File.exist?( cmd )
      logger.warn "#{cmd} not found."
      return false
    end

    customrun_args = (a = Proxy::Puppet::Plugin.settings.customrun_args).is_a?(Array) ? a : a.split(' ')
    shell_command(([escape_for_shell(cmd), customrun_args] + shell_escaped_nodes).flatten)
  end
end
