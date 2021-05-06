require 'facts/facts_api'

map "/facts" do
  use Proxy::Middleware::Authorization
  run Proxy::FactsApi
end
