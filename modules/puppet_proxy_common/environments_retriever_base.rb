class Proxy::Puppet::EnvironmentsRetrieverBase
  attr_reader :puppet_url, :ssl_ca, :ssl_cert, :ssl_key

  def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key)
    @puppet_url = puppet_url
    @ssl_ca = puppet_ssl_ca
    @ssl_cert = puppet_ssl_cert
    @ssl_key = puppet_ssl_key
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
