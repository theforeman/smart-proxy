require 'puppet'

module Proxy::Puppet
  class Initializer
    include Proxy::Log

    def reset_puppet
      Puppet.clear
      if Puppet::PUPPETVERSION.to_i >= 3
        # Used on Puppet 3.0, private method that clears the "initialized or
        # not" state too, so a full config reload takes place and we pick up
        # new environments
        Puppet.settings.send(:clear_everything_for_tests)
      end

      Puppet[:config] = Proxy::Puppet::Plugin.settings.puppet_conf
      logger.info "Initializing from Puppet config file: #{Proxy::Puppet::Plugin.settings.puppet_conf}"

      if Puppet::PUPPETVERSION.to_i >= 3
        Puppet.initialize_settings
      else
        Puppet.parse_config
      end

      # Don't follow imports, the proxy scans for .pp files itself
      Puppet[:ignoreimport] = true if Puppet::PUPPETVERSION.to_i < 4 && Puppet[:parser] != 'future'
    end
  end
end
