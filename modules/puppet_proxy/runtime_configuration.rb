require 'proxy/util'
require 'puppet_proxy/puppet_config'

module Proxy::Puppet::RuntimeConfiguration
  include Proxy::Util

  def puppet_parser
    use_future_parser = puppet_version.to_i >= 4 ||
        (puppet_configuration[:main] && puppet_configuration[:main][:parser] == 'future') ||
        (puppet_configuration[:master] && puppet_configuration[:master][:parser] == 'future')
    use_future_parser ? :future_parser : :legacy_parser
  end

  def environments_retriever
    force = to_bool(Proxy::Puppet::Plugin.settings.puppet_use_environment_api, nil)

    if puppet_version.to_i >= 4
      :api_v3
    elsif puppet_version.to_f < 3.2
      :config_file
    elsif !force.nil? && force
      :api_v2
    elsif !force.nil? && !force
      :config_file
    else
      use_environment_api = !!([:main, :master].find { |s| (puppet_configuration[s] && puppet_configuration[s][:environmentpath] && !puppet_configuration[s][:environmentpath].empty?) })
      use_environment_api ? :api_v2 : :config_file
    end
  end

  def puppet_configuration
    Proxy::Puppet::PuppetConfig.new.get
  end

  def puppet_version
    Puppet::PUPPETVERSION
  end
end
