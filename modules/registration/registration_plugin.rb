module Proxy::Registration
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    plugin :registration, ::Proxy::VERSION
    requires :templates, ::Proxy::VERSION

    load_programmable_settings do |settings|
      settings[:registration_url]&.chomp!('/')
      settings
    end

    validate :registration_url, optional_url: true
    expose_setting :registration_url
  end
end
