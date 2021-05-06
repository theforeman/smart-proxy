require 'tftp/tftp_api'

map "/tftp" do
  use Proxy::Middleware::Authorization
  run Proxy::TFTP::Api
end
