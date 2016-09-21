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

  class EnvironmentClassesApiv3 < ::Proxy::Puppet::ApiRequest
    NOT_MODIFIED = Object.new

    def list_classes(environment, etag, timeout)
      response = send_request("puppet/v3/environment_classes?environment=#{environment}", timeout, "If-None-Match" => etag)

      return [NOT_MODIFIED, response['Etag']] if response.code == '304'
      return [JSON.load(response.body), response['Etag']] if response.is_a? Net::HTTPOK
      raise ::Proxy::Puppet::EnvironmentNotFound, "Could not find environment '#{environment}'" if response.code == '404'
      raise ::Proxy::Error::HttpError.new(response.code, response.body)
    end
  end
end
