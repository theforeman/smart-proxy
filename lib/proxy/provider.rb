class ::Proxy::Provider
  include ::Proxy::Pluggable
  include ::Proxy::Log

  class << self
    attr_reader :provider_factory

    def plugin(plugin_name, aversion, attrs = {})
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      @provider_factory = attrs[:factory]
      ::Proxy::Plugins.plugin_loaded(@plugin_name, @version, self)
    end
  end

  def provider_factory
    self.class.provider_factory
  end

  def configure_plugin(all_plugins)
    logger.info("'#{plugin_name}' settings were initialized with default values: %s" % log_used_default_settings) unless settings.used_defaults.empty?
    validate!(all_plugins)
    ::Proxy::BundlerHelper.require_groups(:default, bundler_group)
    after_activation
    logger.info("Finished initialization of module '#{plugin_name}'")
    true
  rescue Exception => e
    logger.error("Couldn't enable plugin #{plugin_name}: #{e}")
    logger.warn("#{e}:#{e.backtrace.join("\n")}")
    false
  end
end
