require 'registration/registration_api'

map '/register' do
  run Proxy::Registration::Api
end
