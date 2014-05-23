module Proxy::Puppet

  require 'puppet'

  class Initializer
    extend Proxy::Log

    class << self
      def load
        Puppet.clear
        if Puppet::PUPPETVERSION.to_i >= 3
          # Used on Puppet 3.0, private method that clears the "initialized or
          # not" state too, so a full config reload takes place and we pick up
          # new environments
          Puppet.settings.send(:clear_everything_for_tests)
        end

        Puppet[:config] = config
        raise("Cannot read #{config}") unless File.exist?(config)
        logger.info "Initializing from Puppet config file: #{config}"

        if Puppet::PUPPETVERSION.to_i >= 3
          Puppet.initialize_settings
        else
          Puppet.parse_config
        end

        # Don't follow imports, the proxy scans for .pp files itself
        Puppet[:ignoreimport] = true
      end

      def config
        SETTINGS.puppet_conf || File.join(SETTINGS.puppetdir || '/etc/puppet', 'puppet.conf')
      end
    end

  end
end
