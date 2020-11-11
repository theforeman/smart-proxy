module Proxy::Puppet
  class V3EnvironmentsRetriever
    def initialize(api)
      @api = api
    end

    def get(an_environment)
      found = all.find { |e| e.name == an_environment }
      raise Proxy::Puppet::EnvironmentNotFound.new("Could not find environment '#{an_environment}'") unless found
      found
    end

    def all
      response = @api.find_environments
      raise Proxy::Puppet::DataError.new("No environments list in Puppet API response") unless response['environments']
      environments = response['environments'].each_with_object({}) do |item, envs|
        envs[item.first] = item.last['settings']['modulepath'] if item.last && item.last['settings'] && item.last['settings']['modulepath']
      end
      environments.map { |env, path| Proxy::Puppet::Environment.new(env, path) }
    end
  end
end
