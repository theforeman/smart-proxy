require 'puppet_proxy_common/api_request'

module ::Proxy::PuppetCa::PuppetcaHttpApi
  class CaApiv1Request < ::Proxy::Puppet::ApiRequest
    # the key is required but ignored
    def search(key = 'foreman')
      handle_response(send_request("/puppet-ca/v1/certificate_statuses/#{key}"), [], 'Failed to query Puppet CA search v1 API')
    end

    def sign(certname)
      handle_response(put_data("/puppet-ca/v1/certificate_status/#{certname}", 'desired_state' => 'signed'), [Net::HTTPNoContent], 'Failed to set Puppet CA certificate_status v1 API')
    end

    def clean(certname)
      handle_response(put_data("/puppet-ca/v1/certificate_status/#{certname}", 'desired_state' => 'revoked'), [Net::HTTPNoContent, Net::HTTPNotFound, Net::HTTPConflict], 'Failed to set Puppet CA certificate_status v1 API')
      handle_response(delete("/puppet-ca/v1/certificate_status/#{certname}"), [Net::HTTPNoContent, Net::HTTPNotFound], 'Failed to delete Puppet CA certificate_status v1 API')
    end

    private

    def handle_response(a_response, ok_results = [], a_msg = nil)
      return nil if ok_results.include?(a_response.class)
      super(a_response, a_msg)
    end
  end
end
