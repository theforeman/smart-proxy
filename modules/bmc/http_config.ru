require 'bmc/bmc_api'

map "/bmc" do
  run Proxy::BMC::Api
end
