require 'yaml'

class MigrateDhcpSettings < ::Proxy::Migration
  KNOWN_PARAMETERS = {
      :enabled => [:dhcp, :enabled],
      :dhcp_vendor => [:dhcp, :use_provider, :old_provider_name_to_new],
      :dhcp_subnets => [:dhcp, :subnets],
      :dhcp_config => [:dhcp_isc, :config],
      :dhcp_leases => [:dhcp_isc, :leases],
      :dhcp_key_name => [:dhcp_isc, :key_name],
      :dhcp_key_secret => [:dhcp_isc, :key_secret],
      :dhcp_omapi_port => [:dhcp_isc, :omapi_port],
      :dhcp_server => [:dhcp, :server],
  }

  def remap_parameter(aparameter, avalue)
    module_name, parameter_name, converter =
      KNOWN_PARAMETERS.has_key?(aparameter) ? KNOWN_PARAMETERS[aparameter] : [:unknown, aparameter]

    converter.nil? ? [module_name, parameter_name, avalue] : [module_name, parameter_name, send(converter, avalue)]
  end

  def migrate
    dhcp_config = path(src_dir, "settings.d", "dhcp.yml")
    unless File.exist?(dhcp_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(dhcp_config)
    output = migrate_dhcp_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "dhcp.yml"))
    write_to_files(output)
  end

  def old_provider_name_to_new(aname)
    if ['isc', 'native_ms', 'virsh'].include?(aname)
      'dhcp_' + aname
    else
      aname
    end
  end

  def migrate_dhcp_configuration(to_migrate)
    migrated = Hash.new { |h, k| h[k] = Hash.new }
    to_migrate.each do |option, value|
      module_name, parameter_name, parameter_value = remap_parameter(option, value)
      migrated[module_name][parameter_name] = parameter_value
    end
    migrated
  end

  def write_to_files(output)
    output.keys.each do |m|
      next if output[m].empty? || m == :unknown
      File.open(path(dst_dir, "settings.d", "#{m}.yml"), 'w') do |f|
        f.write(strip_ruby_symbol_encoding(output[m].to_yaml))
        if (m == :dhcp) && !output[:unknown].empty?
          f.write "\n# Unparsed options, please review\n"
          f.write(strip_ruby_symbol_encoding(output[:unknown].to_yaml).gsub(/^---/, ''))
        end
      end
    end
  end
end
