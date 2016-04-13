module ::Proxy::PuppetLegacy
  class EnvironmentsApi < ::Proxy::Puppet::ApiRequest
    def find_environments
      handle_response(send_request('v2.0/environments'), "Failed to query Puppet find environments v2 API")
    end
  end
end
