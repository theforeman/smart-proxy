module Proxy::BMC
  class Plugin < Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    plugin :bmc, ::Proxy::VERSION
  end
end
