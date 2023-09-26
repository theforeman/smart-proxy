require 'yaml'

class MigrateAutosignSetting < Proxy::Migration
  def migrate
    puppetca_config = path(src_dir, "settings.d", "puppetca.yml")
    unless File.exist?(puppetca_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(puppetca_config)
    output = migrate_autosign_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "puppetca.yml"))
    write_to_files(output)
  end

  def remap_parameter(aparameter, avalue)
    module_name = :puppetca

    if aparameter == :puppetdir
      parameter_name = :autosignfile
      parameter_value = avalue + '/autosign.conf'
    else
      parameter_name = aparameter
      parameter_value = avalue
    end

    [module_name, parameter_name, parameter_value]
  end

  def migrate_autosign_configuration(to_migrate)
    migrated = Hash.new { |h, k| h[k] = {} }
    to_migrate.each do |option, value|
      module_name, parameter_name, parameter_value = remap_parameter(option, value)
      migrated[module_name][parameter_name] = parameter_value
    end
    migrated
  end

  def write_to_files(output)
    output.keys.each do |m|
      next if output[m].empty? || m == :unknown
      File.write(path(dst_dir, "settings.d", "#{m}.yml"), strip_ruby_symbol_encoding(output[m].to_yaml))
    end
  end
end
