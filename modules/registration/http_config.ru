require 'registration/registration_api'
require 'registration/registration_commands_api'

map '/register' do
  run Proxy::Registration::Api
end

map '/registration_commands' do
  run Proxy::Registration::CommandsApi
end
