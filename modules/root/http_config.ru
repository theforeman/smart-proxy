require 'root/root_api'
require 'root/root_v2_api'

map "/" do
  run Proxy::RootApi
end

map "/v2" do
  use Proxy::Middleware::Authorization
  run Proxy::RootV2Api
end
