require 'root/root_api'
require 'root/protected_root_api'

map "/" do
  run Proxy::RootApi
  run Proxy::ProtectedRootApi
end
