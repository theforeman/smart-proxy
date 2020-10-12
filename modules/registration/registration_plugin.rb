module Proxy::Registration
  class Plugin < ::Proxy::Plugin
    http_rackup_path  File.expand_path("http_config.ru", File.expand_path(__dir__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    plugin :registration, ::Proxy::VERSION
  end
end
