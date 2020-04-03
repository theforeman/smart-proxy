require 'puppet_proxy_common/api_request'

module Proxy::Puppet
  class Apiv3 < ::Proxy::Puppet::ApiRequest
    NOT_MODIFIED = Object.new

    def find_environments
      handle_response(send_request('puppet/v3/environments'), "Failed to query Puppet find environments v3 API")
    end

    def list_classes(environment, etag, timeout)
      response = send_request("puppet/v3/environment_classes?environment=#{environment}", timeout, "If-None-Match" => etag)

      return [NOT_MODIFIED, response['Etag']] if response.code == '304'
      return [JSON.load(response.body), response['Etag']] if response.is_a? Net::HTTPOK
      raise ::Proxy::Puppet::EnvironmentNotFound, "Could not find environment '#{environment}'" if response.code == '404'
      raise ::Proxy::Error::HttpError.new(response.code, response.body)
    end
  end
end
