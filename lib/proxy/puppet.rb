module Proxy::Puppet
  extend Proxy::Log
  extend Proxy::Util
  require 'proxy/puppet/puppet_class'
  require 'proxy/puppet/environment'


  class << self
    require 'open3'
    def run *hosts
      # Search in /opt/ for puppet enterprise users
      default_path = ["/usr/sbin", "/usr/bin", "/opt/puppet/bin"]
      # search for puppet for users using puppet 2.6+
      puppetrun    = which("puppetrun", default_path) || which("puppet", default_path)
      sudo         = which("sudo", "/usr/bin")

      unless puppetrun and sudo
        logger.warn "sudo or puppetrun binary was not found - aborting"
        return false
      end

      puppet_cmd = [puppetrun]
      puppet_cmd += ["kick"] unless puppetrun.include?('puppetrun')

      # Add a --host argument for each client where a run was requested.
      hosts.map { |h| puppet_cmd += ["--host", escape_for_shell(h)] }

      # Returns a boolean with whether or not the command executed successfully.
      Open3.popen3(*puppet_cmd) do |stdin, stdout, stderr|
        stdrout = stdout.read
        if stdrout =~ /finished with exit code 0/
          return true
        else
          logger.warn "The attempted puppetrun failed: \n#{stderr.read}\n#{stdrout}"
          return false
        end
      end
    end
  end
end
