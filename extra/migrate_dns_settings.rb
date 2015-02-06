#!/usr/bin/ruby
#
# Script to migrate foreman-proxy settings.yml
# to plugin form
#
# Greg Sutcliffe <gsutclif@redhat.com> 2014

require 'yaml'

def known_dns_options
  {
      :enabled            => [:dns],
      :dns_provider       => [:dns],
      :dns_key            => [:dns_nsupdate, :dns_nsupdate_gss],
      :dns_server         => [:dns_nsupdate, :dns_nsupdate_gss, :dns_dnscmd],
      :dns_ttl            => [:dns_nsupdate, :dns_nsupdate_gss],
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
          output[m][option] = recognized_dns_provider_name?(value) ? migrate_dns_provider_name(value) : value
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

def write_to_files(output,unknown)
  output.keys.each do |m|
    next if output[m] == {}
    File.open("#{m}.yml",'w') do |f|
      f.write(output[m].to_yaml)
      if m == :dns && unknown != {}
        f.write "\n# Unparsed options, please review\n"
        f.write(unknown.to_yaml.gsub(/^---/,''))
      end
    end
  end
end

def should_save?(data, output)
  data[:dns] != output[:dns]
end

# When running as a script
if __FILE__ == $0 then
  orig_file = ARGV[0] || '/etc/foreman-proxy/settings.d/dns.yml'
  data      = YAML.load_file(orig_file)

  output,unknown = migrate_dns_configuration(data.dup)
  exit(1) unless should_save?(data, output) # it looks like we already have the new style settings
  write_to_files(output,unknown)
  exit(0)
end
