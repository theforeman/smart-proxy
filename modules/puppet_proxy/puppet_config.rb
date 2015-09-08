require 'augeas'

module Proxy::Puppet
  class PuppetConfig
    def get
      Proxy::Puppet::ConfigReader.new(Proxy::Puppet::Plugin.settings.puppet_conf).get
    end
  end

  class ConfigReader
    attr_reader :config

    def initialize(config)
      raise "Puppet config at #{config} was not found" unless File.exist?(config)
      @config = config
    end

    def get
      return @config_hash if @config_hash

      aug = nil
      begin
        aug = ::Augeas::open(nil, nil, ::Augeas::NO_MODL_AUTOLOAD)
        aug.set('/augeas/load/Puppet/lens', 'Puppet.lns')
        aug.set('/augeas/load/Puppet/incl', config)
        aug.load

        @config_hash = Hash.new { |h,k| h[k] = {} }
        aug.match("/files#{config}/*/*[label() != '#comment']").each do |path|
          (section, key) = path.split('/')[-2..-1].map(&:to_sym)
          @config_hash[section][key] = aug.get(path)
        end
      ensure
        aug.close if aug
      end
      @config_hash
    end
  end
end
