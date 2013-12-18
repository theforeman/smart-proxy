require 'proxy/puppet'

module Proxy::Puppet
  class CustomRun < Runner

    def run
      cmd = SETTINGS.customrun_cmd
      unless File.exists?( cmd )
        logger.warn "#{cmd} not found."
        return false
      end

      shell_command( [ escape_for_shell(cmd), SETTINGS.customrun_args, shell_escaped_nodes ] )
    end
  end
end
