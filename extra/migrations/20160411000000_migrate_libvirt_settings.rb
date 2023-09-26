require 'fileutils'
require 'yaml'

class MigrateVirshToLibvirtConfig < Proxy::Migration
  def migrate
    input_yaml = YAML.load_file(path(src_dir, "settings.yml"))
    copy_original_configuration_except("settings.yml",
                                       path("settings.d", "dhcp.yml"), path("settings.d", "dhcp_virsh.yml"),
                                       path("settings.d", "dns.yml"), path("settings.d", "dns_virsh.yml"))

    dhcp_path = path(src_dir, "settings.d", "dhcp.yml")
    write_yaml(path(dst_dir, "settings.d", "dhcp.yml"), transform_dhcp_yaml(YAML.load_file(dhcp_path))) if File.exist?(dhcp_path)

    write_yaml(path(dst_dir, "settings.d", "dhcp_libvirt.yml"), transform_dhcp_libvirt_yaml(input_yaml))

    dns_path = path(src_dir, "settings.d", "dns.yml")
    write_yaml(path(dst_dir, "settings.d", "dns.yml"), transform_dns_yaml(YAML.load_file(dns_path))) if File.exist?(dns_path)
    write_yaml(path(dst_dir, "settings.d", "dns_libvirt.yml"), transform_dns_libvirt_yaml(input_yaml))

    write_yaml(path(dst_dir, "settings.yml"), transform_settings_yaml(input_yaml))
  end

  def transform_settings_yaml(yaml)
    yaml.delete(:virsh_network)
    yaml
  end

  def transform_dns_libvirt_yaml(yaml)
    network = yaml[:virsh_network] || 'default'
    { :network => network }
  end

  def transform_dns_yaml(yaml)
    yaml[:use_provider] = "dns_libvirt" if yaml[:use_provider] == "dns_virsh"
    yaml
  end

  def transform_dhcp_yaml(yaml)
    yaml[:use_provider] = "dhcp_libvirt" if yaml[:use_provider] == "dhcp_virsh"
    yaml
  end

  def transform_dhcp_libvirt_yaml(yaml)
    network = yaml[:virsh_network] || 'default'
    { :network => network }
  end

  def write_yaml(filepath, yaml)
    File.write(filepath, yaml.to_yaml)
  end
end
