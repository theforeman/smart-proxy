class Proxy::PuppetApi::V3ClassesRetriever
  attr_reader :puppet_url, :ssl_ca, :ssl_cert, :ssl_key

  def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key, api = nil)
    @puppet_url = puppet_url
    @ssl_ca = puppet_ssl_ca
    @ssl_cert = puppet_ssl_cert
    @ssl_key = puppet_ssl_key
    @api = api || Proxy::PuppetApi::ResourceTypeApiv3.new(puppet_url, ssl_ca, ssl_cert, ssl_key)
  end

  def convert_to_proxy_var_parameter_representation(puppet_resource_type_response)
    puppet_resource_type_response.inject([]) do |to_return, current_resource|
      params = current_resource['parameters'].inject({}) do |all, current|
        all[current[0]] = (current[1].is_a?(String) && current[1].start_with?('$')) ? "${#{current[1].slice(1..-1)}}" : current[1]
        all
      end
      to_return << ::Proxy::Puppet::PuppetClass.new(current_resource['name'], params)
    end
  end

  def classes_in_environment(environment)
    convert_to_proxy_var_parameter_representation(@api.list_classes(environment, "class"))
  rescue ::Proxy::Error::HttpError => e
    raise Proxy::Puppet::EnvironmentNotFound.new(e.response_body) if e.status_code.to_s == '400' && e.response_body.include?("Could not find environment")
    raise e
  end
end

# A dummy noop service
class Proxy::PuppetApi::NoopClassesCacheInitializer
  def start_service
    # nothing to do, we don't cache classes in this implementation
  end
end
