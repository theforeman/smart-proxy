require 'templates/templates_api'

map "/unattended" do
  run Proxy::TemplatesApi
end
