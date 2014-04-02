module ::Proxy::Settings
  class Plugin < ::OpenStruct
    SHARED_DEFAULTS = { :enabled => false }

    attr_reader :defaults, :used_defaults

    def initialize(default_settings, settings)
      @defaults = SHARED_DEFAULTS.merge(default_settings || {})
      @used_defaults = @defaults.keys - settings.keys
      super(@defaults.merge(settings))
    end

    def method_missing(symbol, *args); nil; end
  end
end
