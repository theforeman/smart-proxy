module Proxy::Registration
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    plugin :registration, ::Proxy::VERSION
    requires :templates, ::Proxy::VERSION
  end
end
