module ::Proxy::Settings
  class Plugin < ::OpenStruct
    SHARED_DEFAULTS = { :enabled => false }
    HTTP_ENABLED = [true, 'http']
    HTTPS_ENABLED = [true, 'https']

    attr_reader :defaults, :used_defaults

    def initialize(default_settings, settings)
      @defaults = SHARED_DEFAULTS.merge(default_settings || {})
      @used_defaults = @defaults.keys - settings.keys
      super(@defaults.merge(settings))
    end

    def self.http_enabled?(setting)
      HTTP_ENABLED.include?(setting)
    end

    def self.https_enabled?(setting)
      HTTPS_ENABLED.include?(setting)
    end
  end
end
