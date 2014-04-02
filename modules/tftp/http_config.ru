require 'tftp/tftp_api'

map "/tftp" do
  run Proxy::TFTP::Api
end
