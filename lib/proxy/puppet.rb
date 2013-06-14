require 'proxy/util'

module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'

  class Runner
    include Proxy::Log
    include Proxy::Util

    def initialize(opts)
      @nodes = opts[:nodes]
    end

    protected
    attr_reader :nodes
    
    def shell_escaped_nodes
      nodes.collect { |n| escape_for_shell(n) }
    end
    
    def shell_command(cmd)
      begin
        c = IO.popen(cmd)
        Process.wait(c.pid)
      rescue Exception => e
        logger.error("Exception '#{e}' when executing '#{cmd}'")
        return false
      end
      logger.warn("Non-null exit code when executing '#{cmd}'") if $?.exitstatus != 0
      $?.exitstatus == 0
    end
  end
end
