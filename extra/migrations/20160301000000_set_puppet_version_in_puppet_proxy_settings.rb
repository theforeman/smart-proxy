require 'yaml'

class SetPuppetVersionInPuppetProxySettings < ::Proxy::Migration
  def migrate
    puppet_config = path(src_dir, "settings.d", "puppet.yml")
    if !File.exist?(puppet_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(puppet_config)
    output = migrate_puppet_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "puppet.yml"))
    write_puppet_config(output)
  end

  def migrate_puppet_configuration(original_config)
    to_return = original_config
    to_return[:puppet_version] = puppet_version
    to_return
  end

  def puppet_version
    require 'puppet'
    Puppet::PUPPETVERSION
  rescue Exception
    "4.3.1"
  end

  def write_puppet_config(output)
    File.open(path(dst_dir, "settings.d", "puppet.yml"),'w') do |f|
      f.write(strip_ruby_symbol_encoding(output.to_yaml))
    end
  end
end
