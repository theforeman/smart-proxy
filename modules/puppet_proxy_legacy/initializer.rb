module Proxy::PuppetLegacy
  class Initializer
    include Proxy::Log
    attr_reader :puppet_conf

    def initialize(puppet_conf)
      @puppet_conf = puppet_conf
    end

    def reset_puppet
      Puppet.clear
      if Puppet::PUPPETVERSION >= "3"
        # Used on Puppet 3.0, private method that clears the "initialized or
        # not" state too, so a full config reload takes place and we pick up
        # new environments
        Puppet.settings.send(:clear_everything_for_tests)
      end

      Puppet[:config] = puppet_conf
      logger.debug "Initializing from Puppet config file: #{puppet_conf}"

      if Puppet::PUPPETVERSION >= "3"
        Puppet.initialize_settings
      else
        Puppet.parse_config
      end

      # Don't follow imports, the proxy scans for .pp files itself
      Puppet[:ignoreimport] = true if Puppet::PUPPETVERSION < "4" && Puppet[:parser] != 'future'
    end
  end
end
