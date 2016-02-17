require 'fileutils'
require 'yaml'

class MigrateVirshSettingsConfig < ::Proxy::Migration
  def migrate
    input_yaml = YAML.load_file(File.join(src_dir, 'settings.yml'))
    write_yaml("dhcp_virsh.yml", transform_dhcp_yaml(input_yaml))
    write_yaml("dns_virsh.yml", transform_dns_yaml(input_yaml))
  end

  def transform_dns_yaml(yaml)
    network = yaml.delete(:virsh_network) || 'default'
    {
      :network => network
    }
  end

  def transform_dhcp_yaml(yaml)
    network = yaml.delete(:virsh_network) || 'default'
    {
      :network => network,
      :leases => "/var/lib/libvirt/dnsmasq/virbr0.status",
    }
  end

  def write_yaml(filepath, yaml)
    dst = path(dst_dir, "settings.d", filepath)
    puts "Writing result to #{dst}"
    File.open(dst, 'w') do |f|
      f.write(yaml.to_yaml)
    end
  end
end
