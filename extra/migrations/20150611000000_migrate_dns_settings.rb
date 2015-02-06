require 'yaml'

class MigrateDnsSettings < ::Proxy::Migration
  def migrate
    dns_config = path(src_dir, "settings.d", "dns.yml")
    if !File.exist?(dns_config)
      duplicate_original_configuration
      return
    end

    to_migrate = YAML.load_file(dns_config)
    output, unknown = migrate_dns_configuration(to_migrate)
    copy_original_configuration_except(path("settings.d", "dns.yml"))
    write_to_files(output, unknown)
  end

  def known_dns_options
    {
        :enabled            => [:dns],
        :dns_provider       => [:dns],
        :dns_key            => [:dns_nsupdate],
        :dns_server         => [:dns_nsupdate, :dns_nsupdate_gss, :dns_dnscmd],
        :dns_ttl            => [:dns],
        :dns_tsig_keytab    => [:dns_nsupdate_gss],
        :dns_tsig_principal => [:dns_nsupdate_gss]
    }
  end

  def migrate_dns_configuration(data)
    output = Hash.new { |h,k| h[k] = Hash.new }

    data.each do |option, value|
      if known_dns_options.include? option
        module_names = known_dns_options[option]
        module_names.each do |m|
          if option == :dns_provider
            output[m][:use_provider] = recognized_dns_provider_name?(value) ? migrate_dns_provider_name(value) : value
          else
            output[m][option] = value
          end
        end
        data.delete(option)
      end
    end

    return output, data
  end

  def migrate_dns_provider_name(aname)
    if recognized_dns_provider_name?(aname)
      'dns_' + aname
    else
      aname
    end
  end

  def recognized_dns_provider_name?(aname)
    ['nsupdate', 'nsupdate_gss', 'virsh', 'dnscmd'].include?(aname)
  end

  def write_to_files(output, unknown)
    output.keys.each do |m|
      next if output[m] == {}
      File.open(path(dst_dir, "settings.d", "#{m}.yml"),'w') do |f|
        f.write(output[m].to_yaml)
        if m == :dns && unknown != {}
          f.write "\n# Unparsed options, please review\n"
          f.write(unknown.to_yaml.gsub(/^---/,''))
        end
      end
    end
  end
end
