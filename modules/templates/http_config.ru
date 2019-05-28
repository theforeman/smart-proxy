require 'templates/templates_unattended_api'
require 'templates/templates_userdata_api'

map "/unattended" do
  run Proxy::TemplatesUnattendedApi
end

map "/userdata" do
  run Proxy::TemplatesUserdataApi
end
