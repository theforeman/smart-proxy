require 'proxy/util'

module Proxy::Puppet::RuntimeConfiguration
  include Proxy::Util

  def classes_retriever
    return :api_v3 if Proxy::Puppet::Plugin.settings.puppet_version.to_s >= '4.0'

    use_future_parser =
      (puppet_configuration[:main] && puppet_configuration[:main][:parser] == 'future') ||
      (puppet_configuration[:master] && puppet_configuration[:master][:parser] == 'future')

    use_cache = !!Proxy::Puppet::Plugin.settings.use_cache

    if use_cache && use_future_parser
      :cached_future_parser
    elsif use_cache && !use_future_parser
      :cached_legacy_parser
    elsif !use_cache && use_future_parser
      :future_parser
    else
      :legacy_parser
    end
  end

  def environments_retriever
    return :api_v3 if Proxy::Puppet::Plugin.settings.puppet_version.to_s >= '4.0'

    force = to_bool(Proxy::Puppet::Plugin.settings.puppet_use_environment_api, nil)
    if Proxy::Puppet::Plugin.settings.puppet_version.to_s < '3.2'
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
end
