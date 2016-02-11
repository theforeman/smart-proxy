require 'puppet_proxy/api_request'

class Proxy::Puppet::PuppetApiV3EnvironmentsRetriever < Proxy::Puppet::EnvironmentsRetrieverBase
  def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key, api = nil)
    super(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key)
    @api = api || Proxy::Puppet::EnvironmentsApiv3.new(puppet_url, ssl_ca, ssl_cert, ssl_key)
  end
end
