require 'wol/wol_api'

map "/wol" do
  run Proxy::WolApi
end
