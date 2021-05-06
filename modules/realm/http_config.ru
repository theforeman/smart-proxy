require 'realm/realm_api'

map "/realm" do
  use Proxy::Middleware::Authorization
  run Proxy::Realm::Api
end
