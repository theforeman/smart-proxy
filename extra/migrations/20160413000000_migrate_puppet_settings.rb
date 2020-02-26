require 'yaml'

class MigratePuppetSettings < ::Proxy::Migration
  KNOWN_PARAMETERS = {
      :enabled => [:puppet, :enabled],
      :puppet_provider => [:puppet, :use_provider],
      :puppet_user => [:puppet_proxy_puppetrun, :puppet_proxy_mcollective, :puppet_user],
      :salt_puppetrun_cmd => [:puppet_proxy_salt, :command],
      :customrun_cmd => [:puppet_proxy_customrun, :command],
      :customrun_args => [:puppet_proxy_customrun, :command_arguments],
      :puppet_url => [:puppet_proxy_puppet_api, :puppet_url],
      :puppet_ssl_ca => [:puppet_proxy_puppet_api, :puppet_ssl_ca],
      :puppet_ssl_cert => [:puppet_proxy_puppet_api, :puppet_ssl_cert],
      :puppet_ssl_key => [:puppet_proxy_puppet_api, :puppet_ssl_key],
      :puppetssh_sudo => [:puppet_proxy_ssh, :use_sudo],
      :puppetssh_command => [:puppet_proxy_ssh, :command],
      :puppetssh_wait => [:puppet_proxy_ssh, :wait],
      :puppetssh_user => [:puppet_proxy_ssh, :user],
      :puppetssh_keyfile => [:puppet_proxy_ssh, :keyfile],
      :mcollective_user => [:puppet_proxy_mcollective, :user],
  }

  def migrate
    puppet_config = path(src_dir, "settings.d", "puppet.yml")
    unless File.exist?(puppet_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(puppet_config)

    output = migrate_puppet_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "puppet.yml"))
    write_to_files(output)
  end

  def remap_parameter(aparameter, avalue)
    module_names_to_parameter = KNOWN_PARAMETERS.has_key?(aparameter) ? KNOWN_PARAMETERS[aparameter] : [:unknown, aparameter]
    parameter_name = module_names_to_parameter.last
    module_names = module_names_to_parameter[0..-2]

    avalue = old_provider_name_to_new(avalue) if parameter_name == :use_provider
    module_names.map { |module_name| [module_name, parameter_name, avalue] }
  end

  def old_provider_name_to_new(aname)
    if ['puppetrun', 'mcollective', 'puppetssh', 'salt', 'customrun'].include?(aname)
      (aname == 'puppetssh') ? 'puppet_proxy_ssh' : 'puppet_proxy_' + aname
    else
      aname
    end
  end

  def migrate_puppet_configuration(to_migrate)
    migrated = Hash.new { |h, k| h[k] = Hash.new }
    to_migrate.each do |option, value|
      remap_parameter(option, value).each { |module_name, parameter_name, parameter_value| migrated[module_name][parameter_name] = parameter_value }
    end

    # deal with puppet_user setting, which used to be global, but has been moved (and renamed) to puppetrun and mcollective modules
    if migrated.has_key?(:puppet_proxy_puppetrun)
      puppetrun_user = migrated[:puppet_proxy_puppetrun].delete(:puppet_user)
      migrated[:puppet_proxy_puppetrun][:user] = puppetrun_user unless puppetrun_user.nil?
    end

    if migrated.has_key?(:puppet_proxy_mcollective)
      puppet_user = migrated[:puppet_proxy_mcollective].delete(:puppet_user)
      unless (migrated[:puppet_proxy_mcollective].has_key?(:user) || puppet_user.nil?)
        migrated[:puppet_proxy_mcollective][:user] = puppet_user
      end
    end

    migrated
  end

  def write_to_files(output)
    output.keys.each do |m|
      next if output[m].empty? || m == :unknown
      File.open(path(dst_dir, "settings.d", "#{m}.yml"), 'w') do |f|
        f.write(strip_ruby_symbol_encoding(output[m].to_yaml))
        if (m == :puppet) && !output[:unknown].empty?
          f.write "\n# Unparsed options, please review\n"
          f.write(strip_ruby_symbol_encoding(output[:unknown].to_yaml).gsub(/^---/, ''))
        end
      end
    end
  end
end
