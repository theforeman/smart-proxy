require 'logs/logs_api'

map "/logs" do
  use Proxy::Middleware::Authorization
  run Proxy::LogsApi
end
