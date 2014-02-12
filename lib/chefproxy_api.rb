require 'proxy/request'
require 'proxy/authentication'

class SmartProxy
  error Proxy::Error::BadRequest do
    log_halt(400, "Bad request : " + env['sinatra.error'].message )
  end

  error Proxy::Error::Unauthorized do
    log_halt(401, "Unauthorized : " + env['sinatra.error'].message )
  end

  post "/api/hosts/facts" do
    Proxy::Authentication::Chef.new.authenticated(request) do |content|
      Proxy::Request::Facts.new.post_facts(content)
    end
  end

  post "/api/reports" do
    Proxy::Authentication::Chef.new.authenticated(request) do |content|
      Proxy::Request::Reports.new.post_report(content)
    end
  end
end
