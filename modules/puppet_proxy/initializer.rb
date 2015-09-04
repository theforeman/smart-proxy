require 'puppet'

module Proxy::Puppet
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
        raise("Cannot read #{File.expand_path(config)}") unless File.exist?(config)
        logger.info "Initializing from Puppet config file: #{config}"

        if Puppet::PUPPETVERSION.to_i >= 3
          Puppet.initialize_settings
        else
          Puppet.parse_config
        end

        # Don't follow imports, the proxy scans for .pp files itself
        # This is only applied when using a version of Puppet older than 4.0 that
        # isn't using the future parser, as the future parser ignores imports by
        # default.
        if Puppet::PUPPETVERSION.to_i < 4 || Puppet[:parser] == 'future'
          Puppet[:ignoreimport] = true
        end
      end

      def config
        Proxy::Puppet::Plugin.settings.puppet_conf || File.join(Proxy::Puppet::Plugin.settings.puppetdir, 'puppet.conf')
      end
    end
  end
end
