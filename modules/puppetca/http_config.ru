require 'puppetca/puppetca_api'

map "/puppet/ca" do
  use Proxy::Middleware::Authorization
  run Proxy::PuppetCa::Api
end
