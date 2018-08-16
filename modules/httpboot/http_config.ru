require 'httpboot/httpboot_api'

map "/EFI" do
  run Proxy::HttpbootApi
end

map "/httpboot" do
  run Proxy::HttpbootApi
end
