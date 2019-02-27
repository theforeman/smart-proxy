require 'proxy/default_di_wirings'
require 'proxy/default_plugin_validators'

class ::Proxy::PluginGroup
  HTTP_ENABLED = [true, 'http']
  HTTPS_ENABLED = [true, 'https']

  include ::Proxy::Log
  attr_reader :plugin, :providers, :state, :di_container

  def initialize(a_plugin, providers = [], di_container = ::Proxy::DependencyInjection::Container.new)
    @plugin = a_plugin
    @state = :uninitialized # :uninitialized -> :starting -> :running, or :uninitialized -> :disabled, or :uninitialized -> :starting -> :failed
    @providers = providers
    @di_container = di_container
    @http_enabled = false
    @https_enabled = false
  end

  def inactive?
    @state == :failed || @state == :disabled
  end

  def http_enabled?
    @http_enabled
  end

  def https_enabled?
    @https_enabled
  end

  def capabilities
    members.map(&:capabilities).compact.flatten
  end

  def settings
    exposed_settings = [members.map { |m| m.exposed_settings }.compact].flatten.uniq.sort
    exposed_settings << 'use_provider' if @plugin.uses_provider?
    Hash[exposed_settings.map { |setting| [setting, @plugin.settings[setting]] }]
  end

  def resolve_providers(all_plugins_and_providers)
    return if inactive?
    return unless @plugin.uses_provider?

    used_providers = [@plugin.settings.use_provider].flatten.map(&:to_sym)
    providers = all_plugins_and_providers.select {|p| used_providers.include?(p[:name].to_sym)}

    not_available = used_providers - providers.map {|p| p[:name].to_sym}

    if not_available.empty?
      logger.debug "Providers #{printable_module_names(used_providers)} are going to be configured for '#{@plugin.plugin_name}'"
      return @providers = providers.map {|p| p[:class]}
    end

    fail_group_with_message("Disabling all modules in the group #{printable_module_names(member_names)}: following providers are not available #{printable_module_names(not_available)}")
  end

  def members
    providers + [plugin]
  end

  def member_names
    members.map {|m| m.plugin_name }
  end

  def printable_module_names(names)
    printable = names.map {|name| "'#{name}'"}.join(", ")
    "[#{printable}]"
  end

  def load_plugin_settings
    settings = plugin.module_loader_class.new(plugin, di_container).load_plugin_settings
    update_group_initial_state(settings[:enabled])
  rescue Exception => e
    fail_group(e)
  end

  def update_group_initial_state(enabled_setting)
    @http_enabled = HTTP_ENABLED.include?(enabled_setting)
    @https_enabled = HTTPS_ENABLED.include?(enabled_setting)
    @state = (http_enabled? || https_enabled?) ? :starting : :disabled
  end

  def set_group_state_to_failed
    @http_enabled = false
    @https_enabled = false
    @state =  :failed
  end

  def load_provider_settings
    return if inactive?
    providers.each do |p|
      p.module_loader_class.new(p, di_container).load_provider_settings(plugin.settings.marshal_dump)
    end
  rescue Exception => e
    fail_group(e)
  end

  def configure
    return if inactive?
    members.each {|p| p.module_loader_class.new(p, di_container).configure_plugin }
    @state = :running
  rescue Exception => e
    stop_services
    fail_group(e)
  end

  def fail_group(an_exception)
    fail_group_with_message("Disabling all modules in the group #{printable_module_names(member_names)} due to a failure in one of them: #{an_exception}", an_exception.backtrace)
  end

  def fail_group_with_message(a_message, an_exception = nil)
    set_group_state_to_failed
    logger.error(a_message, an_exception)
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
    loaded_plugins = plugins.loaded.select {|plugin| plugin[:class].ancestors.include?(::Proxy::Plugin)}

    grouped_with_providers = loaded_plugins.map {|p| ::Proxy::PluginGroup.new(p[:class], [], Proxy::DependencyInjection::Container.new)}

    plugins.update(current_state_of_modules(plugins.loaded, grouped_with_providers))

    # load main plugin settings, as this may affect which providers will be selected
    grouped_with_providers.each {|group| group.load_plugin_settings}

    plugins.update(current_state_of_modules(plugins.loaded, grouped_with_providers))

    #resolve provider names to classes
    grouped_with_providers.each {|group| group.resolve_providers(plugins.loaded)}

    # validate prerequisite versions and availability
    all_enabled = all_enabled_plugins_and_providers(grouped_with_providers)
    grouped_with_providers.each do |group|
      next if group.inactive?
      group.validate_dependencies_or_fail(all_enabled)
    end

    # load provider plugin settings
    grouped_with_providers.each {|group| group.load_provider_settings }

    plugins.update(current_state_of_modules(plugins.loaded, grouped_with_providers))

    # configure each plugin & providers
    grouped_with_providers.each {|group| group.configure }

    # validate prerequisites again, as some may have been disabled during loading
    all_enabled = all_enabled_plugins_and_providers(grouped_with_providers)
    grouped_with_providers.each do |group|
      next if group.inactive?
      group.validate_dependencies_or_fail(all_enabled)
    end

    plugins.update(current_state_of_modules(plugins.loaded, grouped_with_providers))
  end

  def current_state_of_modules(all_plugins, all_groups)
    to_update = all_plugins.dup
    all_groups.each do |group|
      # note that providers do not use http_enabled and https_enabled
      updated = to_update.find {|loaded_plugin| loaded_plugin[:name] == group.plugin.plugin_name}
      updated[:di_container] = group.di_container
      updated[:state] = group.state
      updated[:http_enabled] = group.http_enabled?
      updated[:https_enabled] = group.https_enabled?
      updated[:capabilities] = group.capabilities
      updated[:settings] = group.settings
      group.providers.each do |group_member|
        updated = to_update.find {|loaded_plugin| loaded_plugin[:name] == group_member.plugin_name}
        updated[:di_container] = group.di_container
        updated[:state] = group.state
      end
    end
    to_update
  end

  def all_enabled_plugins_and_providers(all_groups)
    all_groups.inject({}) do |all, group|
      group.members.each {|p| all[p.plugin_name] = p} unless group.inactive?
      all
    end
  end
end

module ::Proxy::LegacyRuntimeConfigurationLoader
  def configure_plugin
    plugin.class_eval(&plugin.after_activation_blk)
    logger.info("Successfully initialized '#{plugin.plugin_name}'")
  rescue Exception => e
    logger.error "Couldn't enable '#{plugin.plugin_name}'", e
    ::Proxy::LogBuffer::Buffer.instance.failed_module(plugin.plugin_name, e.message)
  end
end

module ::Proxy::DefaultRuntimeConfigurationLoader
  def configure_plugin
    wire_up_dependencies(plugin.di_wirings, plugin.settings.marshal_dump, di_container)
    start_services(plugin.services, di_container)
    logger.info("Successfully initialized '#{plugin.plugin_name}'")
  rescue Exception => e
    logger.error "Couldn't enable '#{plugin.plugin_name}'", e
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
  def load_plugin_settings
    load_settings({}) {|s| log_used_settings(s)}
  end

  def load_provider_settings(main_plugin_settings)
    load_settings(main_plugin_settings) {|s| log_provider_settings(s)}
  end

  def load_settings(main_plugin_settings)
    config_file_settings = load_configuration_file(plugin.settings_file)

    merged_with_defaults = plugin.default_settings.merge(config_file_settings)

    return merged_with_defaults unless module_enabled?(merged_with_defaults)

    # load dependencies before loading custom settings and running validators -- they may need those classes
    ::Proxy::BundlerHelper.require_groups(:default, plugin.bundler_group_name)
    load_classes

    config_merged_with_main = merge_settings(merged_with_defaults, main_plugin_settings)
    settings = load_programmable_settings(config_merged_with_main)

    plugin.settings = ::Proxy::Settings::Plugin.new({}, settings)

    yield settings

    validate_settings(plugin, settings)

    settings
  end

  def module_enabled?(user_settings)
    return true if plugin.ancestors.include?(::Proxy::Provider)
    !!user_settings[:enabled]
  end

  def load_configuration_file(settings_file)
    begin
      settings = Proxy::Settings.read_settings_file(settings_file)
    rescue Errno::ENOENT
      logger.warn("Couldn't find settings file #{::Proxy::SETTINGS.settings_directory}/#{settings_file}. Using default settings.")
      settings = {}
    end
    settings
  end

  def merge_settings(provider_settings, main_plugin_settings)
    main_plugin_settings.delete(:enabled)
    # all modules have 'enabled' setting, we ignore it when looking for duplicate setting names
    if !(overlap = main_plugin_settings.keys - (main_plugin_settings.keys - provider_settings.keys)).empty?
      raise Exception, "Provider '#{plugin.plugin_name}' settings conflict with the main plugin's settings: #{overlap}"
    end
    provider_settings.merge(main_plugin_settings)
  end

  def log_used_settings(settings)
    log_provider_settings(settings)
    logger.debug("'%s' ports: 'http': %s, 'https': %s" % [plugin.plugin_name,
                                                          ::Proxy::PluginGroup::HTTP_ENABLED.include?(settings[:enabled]),
                                                          ::Proxy::PluginGroup::HTTPS_ENABLED.include?(settings[:enabled])])
  end

  def log_provider_settings(settings)
    default_settings = plugin.plugin_default_settings
    sorted_keys = settings.keys.map(&:to_s).sort.map(&:to_sym) # ruby 1.8.7 doesn't support sorting of symbols
    to_log = sorted_keys.map {|k| "'%s': %s%s" % [k, settings[k], (default_settings.include?(k) && default_settings[k] == settings[k]) ? " (default)" : ""] }.join(", ")
    logger.debug "'%s' settings: %s" % [plugin.plugin_name, to_log]
  end

  def load_programmable_settings(settings)
    plugin.programmable_settings.load_programmable_settings(settings) unless plugin.programmable_settings.nil?
    settings
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
      raise Exception, "Encountered an unknown validator '#{validator[:name]}' when validating '#{plugin.plugin_name}' module." if validator_class.nil?
      validator_class.new(plugin, validator[:setting], validator[:args], validator[:predicate]).evaluate_predicate_and_validate!(config)
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
