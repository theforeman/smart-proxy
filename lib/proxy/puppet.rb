require 'proxy/util'

module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'

  class ApiError < ::StandardError; end
  class ConfigurationError < ::StandardError; end
  class DataError < ::StandardError; end

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

    def shell_command(cmd, wait = true)
      begin
        c = popen(cmd)
        unless wait
          Process.detach(c.pid)
          return 0
        end
        Process.wait(c.pid)
      rescue Exception => e
        logger.error("Exception '#{e}' when executing '#{cmd}'")
        return false
      end
      logger.warn("Non-null exit code when executing '#{cmd}'") if $?.exitstatus != 0
      $?.exitstatus == 0
    end

    def popen(cmd)
      # 1.8.7 note: this assumes that cli options are space-separated
      cmd = cmd.join(' ') unless RUBY_VERSION > '1.8.7'
      logger.debug("about to execute: #{cmd}")
      IO.popen(cmd)
    end
  end
end
