module Proxy::PuppetApi
  class EnvironmentsApiv3 < ::Proxy::Puppet::ApiRequest
    def find_environments
      handle_response(send_request('puppet/v3/environments'), "Failed to query Puppet find environments v3 API")
    end
  end

  class ResourceTypeApiv3 < ::Proxy::Puppet::ApiRequest
    # kind (optional) can be 'class', 'node', or 'defined_type'
    def list_classes(environment, kind = nil)
      kind_filter = kind.nil? || kind.empty? ? "" : "kind=#{kind}&"
      response = send_request("puppet/v3/resource_types/*?#{kind_filter}&environment=#{environment}")
      response.code == '404' ? [] : handle_response(response) # resource api responds with a 404 if filter returns no results
    end
  end
end
