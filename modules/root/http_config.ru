require 'root/root_api'

map "/" do
  run Proxy::RootApi
end
