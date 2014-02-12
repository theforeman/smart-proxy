require 'openssl'
require 'json'

require 'proxy/request'
require 'proxy/abrtproxy'

STATUS_ACCEPTED = 202

class SmartProxy
  post "/abrt/reports/new/" do
    begin
      cn = Proxy::AbrtProxy::common_name request
    rescue Proxy::Error::Unauthorized => e
      log_halt 403, "Client authentication failed: #{e.message}"
    end

    ureport_json = request['file'][:tempfile].read
    ureport = JSON.parse(ureport_json)

    #forward to FAF
    response = nil
    if SETTINGS.abrt_server_url
      begin
        result = Proxy::AbrtProxy::faf_request "/reports/new/", ureport_json
        response = result.body if result.code.to_s == STATUS_ACCEPTED.to_s
      rescue RuntimeError => e
        logger.error "Unable to forward to ABRT server: #{e}"
      end
    end
    if not response
      # forwarding is not configured or failed
      # FAF source that generates replies is in src/webfaf/reports/views.py
      response = { "result" => false,
                   "message" => "Report forwarded to Foreman server" }.to_json
    end

    #send report to Foreman
    begin
      foreman_report = Proxy::AbrtProxy::create_report cn, ureport
      Proxy::Request::Reports.new.post_report(foreman_report.to_json)
    rescue RuntimeError => e
      log_halt 503, "Unable to forward to Foreman server: #{e}"
    end

    status STATUS_ACCEPTED
    response
  end

  post "/abrt/reports/:action/" do
    # pass through to real FAF if configured
    if SETTINGS.abrt_server_url
      body = request['file'][:tempfile].read
      result = Proxy::AbrtProxy::faf_request "/reports/#{params[:action]}/", body
      if result
        status result.code
        result.body
      else
        log_halt 503, "ABRT server unavailable"
      end
    else
      log_halt 501, "foreman-proxy does not implement /reports/#{params[:action]}/"
    end
  end
end
