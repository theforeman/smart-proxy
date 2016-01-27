require 'logs/logs_api'

map "/logs" do
  run Proxy::LogsApi
end
