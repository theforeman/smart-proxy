class ::Proxy::Provider
  extend ::Proxy::Pluggable

  class << self
    attr_reader :provider_factory

    def plugin(plugin_name, aversion, attrs = {})
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      @provider_factory = attrs[:factory]
      ::Proxy::Plugins.instance.plugin_loaded(@plugin_name, @version, self)
    end
  end

  def provider_factory
    self.class.provider_factory
  end
end
