require 'fileutils'
require 'yaml'

class MigrateVirshToLibvirtConfig < ::Proxy::Migration
  def migrate
    input_yaml = YAML.load_file(path(src_dir, "settings.yml"))
    copy_original_configuration_except("settings.yml", path("settings.d", "dhcp_virsh.yml"), path("settings.d", "dns_virsh.yml"))
    write_yaml(path(dst_dir, "settings.d", "dhcp_libvirt.yml"), transform_dhcp_yaml(input_yaml))
    write_yaml(path(dst_dir, "settings.d", "dns_libvirt.yml"), transform_dns_yaml(input_yaml))
    write_yaml(path(dst_dir, "settings.yml"), transform_settings_yaml(input_yaml))
  end

  def transform_settings_yaml(yaml)
    yaml.delete(:virsh_network)
    yaml
  end

  def transform_dns_yaml(yaml)
    network = yaml[:virsh_network] || 'default'
    { :network => network }
  end

  def transform_dhcp_yaml(yaml)
    network = yaml[:virsh_network] || 'default'
    { :network => network }
  end

  def write_yaml(filepath, yaml)
    File.open(filepath, 'w') do |f|
      f.write(yaml.to_yaml)
    end
  end
end
