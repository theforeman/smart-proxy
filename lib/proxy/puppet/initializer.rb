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

        if SETTINGS.puppet_conf
          Puppet[:config] = SETTINGS.puppet_conf
          raise("Cannot read #{Puppet[:config]}") unless File.exist?(Puppet[:config])
        elsif Puppet::PUPPETVERSION.to_i >= 3
          Puppet[:config] = "/etc/puppet/puppet.conf"
        end
        logger.info "Initializing from Puppet config file: #{Puppet[:config]}"

        if Puppet::PUPPETVERSION.to_i >= 3
          # Initializing Puppet directly and not via the Faces API, so indicate
          # the run mode to parse [master].  Don't use --run_mode=master or
          # bug #17492 is hit and Puppet can't parse it.
          Puppet.settings.initialize_global_settings(['--config', Puppet[:config], '--run_mode', 'master'])
          Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(Puppet::Util::RunMode['master']))
        else
          Puppet.parse_config
        end

        # Don't follow imports, the proxy scans for .pp files itself
        Puppet[:ignoreimport] = true
      end
    end

  end
end
