require 'httpboot/httpboot_api'

map "/EFI" do
  run Proxy::HttpbootApi
end

map "/httpboot" do
  run Proxy::HttpbootApi
end

map "/grub2" do
  run Proxy::HttpbootApi
end

map "/grub.cfg" do
  run Proxy::HttpbootApi
end
