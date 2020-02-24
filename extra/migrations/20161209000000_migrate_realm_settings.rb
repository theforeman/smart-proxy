require 'yaml'

class MigrateRealmSettings < ::Proxy::Migration
  KNOWN_PARAMETERS = {
      :enabled => [:realm, :enabled],
      :realm_provider => [:realm, :use_provider],
      :realm_keytab => [:realm_freeipa, :keytab_path],
      :realm_principal => [:realm_freeipa, :principal],
      :freeipa_remove_dns => [:realm_freeipa, :remove_dns],
  }

  def migrate
    realm_config = path(src_dir, "settings.d", "realm.yml")
    unless File.exist?(realm_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(realm_config)
    output = migrate_realm_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "realm.yml"))
    write_to_files(output)
  end

  def remap_parameter(aparameter, avalue)
    module_name, parameter_name, converter =
      KNOWN_PARAMETERS.has_key?(aparameter) ? KNOWN_PARAMETERS[aparameter] : [:unknown, aparameter]
    converter.nil? ? [module_name, parameter_name, avalue] : [module_name, parameter_name, send(converter, avalue)]
  end

  def migrate_realm_configuration(to_migrate)
    migrated = Hash.new { |h,k| h[k] = Hash.new }
    to_migrate.each do |option, value|
      module_name, parameter_name, parameter_value = remap_parameter(option, value)
      migrated[module_name][parameter_name] = parameter_value
    end
    migrated[:realm][:use_provider] = 'realm_freeipa'
    migrated
  end

  def write_to_files(output)
    output.keys.each do |m|
      next if output[m].empty? || m == :unknown
      File.open(path(dst_dir, "settings.d", "#{m}.yml"),'w') do |f|
        f.write(strip_ruby_symbol_encoding(output[m].to_yaml))
        if (m == :realm) && !output[:unknown].empty?
          f.write "\n# Unparsed options, please review\n"
          f.write(strip_ruby_symbol_encoding(output[:unknown].to_yaml).gsub(/^---/,''))
        end
      end
    end
  end
end
