require 'root/root_api'
require 'root/logs_api'

map "/" do
  run Proxy::RootApi
end

map "/logs" do
  run Proxy::LogsApi
end
