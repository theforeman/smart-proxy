module Proxy::PuppetApi
  class V3EnvironmentsRetriever < Proxy::Puppet::EnvironmentsRetrieverBase
    def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key, api = nil)
      super(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key)
      @api = api || Proxy::PuppetApi::EnvironmentsApiv3.new(puppet_url, ssl_ca, ssl_cert, ssl_key)
    end
  end
end
