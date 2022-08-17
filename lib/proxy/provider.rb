class ::Proxy::Provider
  extend ::Proxy::Pluggable

  class << self
    def plugin(plugin_name, aversion, attrs = {})
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      ::Proxy::Plugins.instance.plugin_loaded(@plugin_name, @version, self)
    end
  end
end
