require 'puppetca/puppetca_api'

map "/puppet/ca" do
  run Proxy::PuppetCa::Api
end
