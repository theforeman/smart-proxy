require 'realm/realm_api'

map "/realm" do
  run Proxy::Realm::Api
end
