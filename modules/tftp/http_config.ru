require 'tftp/tftp_api'
require 'tftp/tftp_system_image_api'

map "/tftp" do
  run Proxy::TFTP::Api
end

map "/tftp/system_image" do
  run Proxy::TFTP::SystemImageApi
end
