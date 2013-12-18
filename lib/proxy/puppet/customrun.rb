require 'proxy/puppet'
require 'yaml'

module Proxy::Puppet
  class CustomRun < Runner

    def run

      begin
        settings = YAML.load(File.read(Pathname.new(__FILE__).join("..","..","..","..","config","settings.yml")))
      rescue Exception => e
        logger.error "failed to load configuration #{e}"
        return false
      end

      cmd = settings[:customrun][:cmd]

      unless File.exists?( cmd )
        logger.warn "#{cmd} not found."
        return false
      end

      shell_command( [ cmd, settings[:customrun][:args], shell_escaped_nodes ] )
    end
  end
end
