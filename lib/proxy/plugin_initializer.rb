require 'proxy/default_di_wirings'
require 'proxy/default_plugin_validators'

class ::Proxy::PluginGroup
  include ::Proxy::Log
  attr_reader :plugin, :providers, :state, :di_container

  def initialize(a_plugin, providers = [], di_container = ::Proxy::DependencyInjection::Container.new)
    @plugin = a_plugin
    @state = :starting
    @providers = providers
    @di_container = di_container
  end

  def failed?
    @state == :failed
  end

  def resolve_providers(all_plugins_and_providers)
    return if failed?
    return unless @plugin.uses_provider?

    used_providers = [@plugin.settings.use_provider].flatten.map(&:to_sym)
    providers = all_plugins_and_providers.select {|p| used_providers.include?(p[:name].to_sym)}

    not_available = used_providers - providers.map {|p| p[:name].to_sym}
    return @providers = providers.map {|p| p[:class]} if not_available.empty?

    fail_group_with_message("Disabling all modules in the group '#{member_names.join(', ')}': following providers are not available #{not_available}")
  end

  def members
    providers + [plugin]
  end

  def member_names
    members.map {|m| m.plugin_name }
  end

  def load_plugin_settings
    plugin.module_loader_class.new(plugin, di_container).load_settings
  rescue Exception => e
    fail_group(e)
  end

  def load_provider_settings
    return if failed?
    providers.each do |p|
      begin
        p.module_loader_class.new(p, di_container).load_settings(plugin.settings.marshal_dump)
      rescue Exception => e
        fail_group(e)
      end
    end
  end

  def configure
    return if failed?
    members.each {|p| p.module_loader_class.new(p, di_container).configure_plugin }
    @state = :running
  rescue Exception => e
    stop_services
    fail_group(e)
  end

  def fail_group(an_exception)
    fail_group_with_message("Disabling all modules in the group '#{member_names.join(', ')}' due to a failure in one of them: #{an_exception}", an_exception.backtrace)
  end

  def fail_group_with_message(a_message, a_backtrace = nil)
    @state = :failed
    logger.error(a_message, a_backtrace)
    members.each do |m|
      ::Proxy::LogBuffer::Buffer.instance.failed_module(m.plugin_name, a_message)
    end
  end

  def stop_services
    members.each do |member|
      member.services.map {|label| di_container.get_dependency(label)}.each {|service| service.stop if service.respond_to?(:stop)}
    end
  end

  def validate_dependencies_or_fail(enabled_providers_and_plugins)
    members.each {|p| validate_dependencies!(p, p.dependencies, enabled_providers_and_plugins)}
  rescue Exception => e
    stop_services
    fail_group(e)
  end

  def validate_dependencies!(plugin, dependencies, enabled_providers_and_plugins)
    dependencies.each do |dep|
      found = enabled_providers_and_plugins[dep.name]
      raise ::Proxy::PluginNotFound, "'#{dep.name}' required by '#{plugin.plugin_name}' could not be found." unless found
      unless ::Gem::Dependency.new('', dep.version).match?('', found.cleanup_version(found.version))
        raise ::Proxy::PluginVersionMismatch, "Available version '#{found.version}' of '#{dep.name}' doesn't match version '#{dep.version}' required by '#{plugin.plugin_name}'"
      end
    end
  end
end

class ::Proxy::PluginInitializer
  attr_accessor :plugins

  def initialize(plugins)
    @plugins = plugins
  end

  def initialize_plugins
    # find all enabled plugins
    enabled_plugins = plugins.loaded.select {|plugin| plugin[:class].ancestors.include?(::Proxy::Plugin) && plugin[:class].enabled}

    grouped_with_providers = enabled_plugins.map {|p| ::Proxy::PluginGroup.new(p[:class], [], Proxy::DependencyInjection::Container.new)}

    update_plugin_states(plugins, grouped_with_providers)

    # load main plugin settings, as this may affect which providers will be selected
    grouped_with_providers.each {|group| group.load_plugin_settings }

    #resolve provider names to classes
    grouped_with_providers.each {|group| group.resolve_providers(plugins.loaded)}

    # load provider plugin settings
    grouped_with_providers.each {|group| group.load_provider_settings }

    # configure each plugin & providers
    grouped_with_providers.each {|group| group.configure }

    # check prerequisites
    all_enabled = all_enabled_plugins_and_providers(grouped_with_providers)
    grouped_with_providers.each do |group|
      next if group.failed?
      group.validate_dependencies_or_fail(all_enabled)
    end

    update_plugin_states(plugins, grouped_with_providers)
  end

  def update_plugin_states(all_plugins, all_groups)
    to_update = all_plugins.loaded.dup
    all_groups.each do |group|
      group.members.each do |group_member|
        updated = to_update.find {|loaded_plugin| loaded_plugin[:name] == group_member.plugin_name}
        updated[:di_container] = group.di_container
        updated[:state] = group.state
      end
    end
    all_plugins.update(to_update)
  end

  def all_enabled_plugins_and_providers(all_groups)
    all_groups.inject({}) do |all, group|
      group.members.each {|p| all[p.plugin_name] = p} unless group.failed?
      all
    end
  end
end

module ::Proxy::LegacyRuntimeConfigurationLoader
  def configure_plugin
    plugin.class_eval(&plugin.after_activation_blk)
    logger.info("Successfully initialized '#{plugin.plugin_name}'")
  rescue Exception => e
    logger.error("Couldn't enable '#{plugin.plugin_name}': #{e}", e.backtrace)
    ::Proxy::LogBuffer::Buffer.instance.failed_module(plugin.plugin_name, e.message)
  end
end

module ::Proxy::DefaultRuntimeConfigurationLoader
  def configure_plugin
    wire_up_dependencies(plugin.di_wirings, plugin.settings.marshal_dump, di_container)
    start_services(plugin.services, di_container)
    logger.info("Successfully initialized '#{plugin.plugin_name}'")
  rescue Exception => e
    logger.error("Couldn't enable '#{plugin.plugin_name}': #{e}", e.backtrace)
    ::Proxy::LogBuffer::Buffer.instance.failed_module(plugin.plugin_name, e.message)
    raise e
  end

  def wire_up_dependencies(di_wirings, config, container)
    [::Proxy::DefaultDIWirings, di_wirings].compact.each do |wiring|
      wiring.load_dependency_injection_wirings(container, config)
    end
  end

  def start_services(services, container)
    services.each do |s|
      instance = container.get_dependency(s)
      instance.start if instance.respond_to?(:start)
    end
  end
end

module ::Proxy::DefaultSettingsLoader
  def load_settings(main_plugin_settings = {})
    settings_file_config = load_configuration(plugin.settings_file)
    merged_with_defaults = plugin.default_settings.merge(settings_file_config)

    # load dependencies before loading custom settings and running validators -- they may need those classes
    ::Proxy::BundlerHelper.require_groups(:default, plugin.bundler_group_name)
    load_classes

    config_merged_with_main = merge_settings(merged_with_defaults, main_plugin_settings)
    settings = load_programmable_settings(config_merged_with_main)

    plugin.settings = ::Proxy::Settings::Plugin.new({}, settings)
    logger.debug("'#{plugin.plugin_name}' settings: #{used_settings(settings)}")

    validate_settings(plugin, settings)

    settings
  end

  def merge_settings(provider_settings, main_plugin_settings)
    main_plugin_settings.delete(:enabled)
    # all modules have 'enabled' setting, we ignore it when looking for duplicate setting names
    if !(overlap = main_plugin_settings.keys - (main_plugin_settings.keys - provider_settings.keys)).empty?
      raise "Provider '#{plugin.plugin_name}' settings conflict with the main plugin's settings: #{overlap}"
    end
    provider_settings.merge(main_plugin_settings)
  end

  def used_settings(settings)
    default_settings = plugin.plugin_default_settings
    sorted_keys = settings.keys.map(&:to_s).sort # ruby 1.8.7 doesn't support sorting of symbols
    sorted_keys.map {|k| "'%s': %s%s" % [k, settings[k.to_sym], (default_settings.include?(k) && default_settings[k] == settings[k]) ? " (default)" : ""] }.join(", ")
  end

  def load_configuration(settings_file)
    begin
      settings = Proxy::Settings.read_settings_file(settings_file)
    rescue Errno::ENOENT
      logger.warn("Couldn't find settings file #{::Proxy::SETTINGS.settings_directory}/#{settings_file}. Using default settings.")
      settings = {}
    end
    settings
  end

  def load_programmable_settings(settings)
    plugin.programmable_settings.nil? ? settings : plugin.programmable_settings.load_programmable_settings(settings)
  end

  def load_classes
    plugin.class_loader.load_classes unless plugin.class_loader.nil?
  end

  def validate_settings(plugin, config)
    result = execute_validators(plugin.plugin_default_settings.keys.map {|k| {:name => :presence, :setting => k}}, config)
    result + execute_validators(plugin.validations, config)
  end

  def execute_validators(validations, config)
    available_validators = Proxy::DefaultPluginValidators.validators.merge(plugin.custom_validators)

    validations.inject([]) do |all, validator|
      validator_class = available_validators[validator[:name]]
      raise "Found an unknown validator '#{validator[:name]}' when validating '#{plugin.plugin_name}' module." if validator_class.nil?
      validator_class.new(plugin, validator[:setting], validator[:args], validator[:predicate]).validate!(config)
      all << {:class => validator_class, :setting => validator[:setting], :args => validator[:args], :predicate => validator[:predicate]}
    end
  end
end

class ::Proxy::DefaultModuleLoader
  include ::Proxy::Log
  include ::Proxy::DefaultSettingsLoader
  include ::Proxy::DefaultRuntimeConfigurationLoader

  attr_reader :plugin, :di_container

  def initialize(a_plugin, di_container)
    @di_container = di_container
    @plugin = a_plugin
  end
end

class ::Proxy::LegacyModuleLoader
  include ::Proxy::Log
  include ::Proxy::DefaultSettingsLoader
  include ::Proxy::LegacyRuntimeConfigurationLoader

  attr_reader :plugin, :di_container

  def initialize(a_plugin, di_container)
    @di_container = di_container
    @plugin = a_plugin
  end
end
