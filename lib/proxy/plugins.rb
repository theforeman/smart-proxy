class ::Proxy::PluginNotFound < ::StandardError; end
class ::Proxy::PluginVersionMismatch < ::StandardError; end
class ::Proxy::PluginMisconfigured < ::StandardError; end
class ::Proxy::PluginProviderNotFound < ::StandardError; end
class ::Proxy::PluginLoadingAborted < ::StandardError; end

class ::Proxy::Plugins
  include ::Proxy::Log

  def self.instance
    @instance ||= ::Proxy::Plugins.new
  end

  def plugin_loaded(a_name, a_version, a_class)
    self.loaded += [{:name => a_name, :version => a_version, :class => a_class, :state => :uninitialized}]
  end

  #
  # each element of the list is a hash containing:
  #
  # :name: module name
  # :version: module version
  # :class: module class
  # :state: one of :uninitialized, :loaded, :staring, :running, :disabled, or :failed
  # :di_container: dependency injection container used by the module
  # :http_enabled: true or false (not used by providers)
  # :https_enabled: true or false (not used by providers)
  #
  def loaded
    @loaded ||= []
  end

  attr_writer :loaded

  def update(updated_plugins)
    updated_plugins.each do |updated|
      loaded.delete_if { |p| p[:name] == updated[:name] }
      loaded << updated
    end
  end

  def find
    loaded.find do |plugin|
      yield plugin
    end
  end

  def select
    loaded.select do |plugin|
      yield plugin
    end
  end

  #
  # below are methods that are going to be removed/deprecated
  #

  def enabled_plugins
    logger.warn('Proxy::Plugins#enabled_plugins is deprecated and will be removed in 3.5. Please use #select instead')
    loaded.select { |p| p[:state] == :running && p[:class].ancestors.include?(::Proxy::Plugin) }.map { |p| p[:class] }
  end

  def plugin_enabled?(plugin_name)
    logger.warn('Proxy::Plugins#plugin_enabled? is deprecated and will be removed in 3.5. Please use #find instead')
    plugin = loaded.find { |p| p[:name] == plugin_name.to_sym }
    plugin.nil? ? false : plugin[:state] == :running
  end

  def find_plugin(plugin_name)
    logger.warn('Proxy::Plugins#find_plugin is deprecated and will be removed in 3.5. Please use #find instead')
    p = loaded.find { |plugin| plugin[:name] == plugin_name.to_sym }
    return p[:class] if p
  end

  def find_provider(provider_name)
    logger.warn('Proxy::Plugins#find_provider is deprecated and will be removed in 3.5. Please use #find instead')
    provider = loaded.find { |p| p[:name] == provider_name.to_sym }
    raise ::Proxy::PluginProviderNotFound, "Provider '#{provider_name}' could not be found" if provider.nil? || !provider[:class].ancestors.include?(::Proxy::Provider)
    provider[:class]
  end
end
