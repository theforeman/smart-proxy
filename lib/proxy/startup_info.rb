require 'proxy/request'
require 'socket'

module Proxy
  class StartupInfo < Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    def put_features
      params = { :proxy_name => Socket.gethostname, :startup_refresh => true }.to_json
      req = request_factory.create_put("/api/v2/smart_proxies/startup_refresh", params)
      response = send_request(req)
      logger.warn "Failed to notify Foreman on startup. Received response: #{response.code} #{response.msg}" unless response.code == "200"
      response
    end
  end
end
