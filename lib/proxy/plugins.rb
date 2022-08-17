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
end
