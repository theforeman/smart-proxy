require 'puppet_proxy/api_request'

class Proxy::Puppet::PuppetApiV3EnvironmentsRetriever
  def all
    response = Proxy::Puppet::EnvironmentsApiv3.new.find_environments
    raise Proxy::Puppet::DataError.new("No environments list in Puppet API response") unless response['environments']
    environments = response['environments'].inject({}) do |envs, item|
      envs[item.first] = item.last['settings']['modulepath'] if item.last && item.last['settings'] && item.last['settings']['modulepath']
      envs
    end
    environments.map { |env, path| Proxy::Puppet::Environment.new(:name => env, :paths => path) }
  end
end
