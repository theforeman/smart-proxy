#
# Script to migrate forema-proxy settings.yml
# to plugin form
#
# Greg Sutcliffe <gsutclif@redhat.com> 2014

require 'fileutils'
require 'yaml'

class MigrateMonolithicConfig < ::Proxy::Migration
  def migrate
    # Skip the migration if we are dealing with modularized proxy
    if File.directory?(File.join(src_dir, "settings.d"))
      FileUtils.cp_r(File.join(src_dir, '.'), dst_dir)
      return
    end

    to_migrate = YAML.load_file(File.join(src_dir, 'settings.yml'))
    output, unknown = migrate_monolithic_config(to_migrate)
    write_to_files(output, unknown)
  end

  def modules
    [ :settings, :tftp, :dns, :dhcp, :puppet, :puppetca, :bmc, :chef, :realm ]
  end

  def known_options
    {
        :daemon             => :settings,
        :daemon_pid         => :settings,
        :log_file           => :settings,
        :log_level          => :settings,
        :port               => :settings,
        :ssl_ca_file        => :settings,
        :ssl_certificate    => :settings,
        :ssl_private_key    => :settings,
        :trusted_hosts      => :settings,
        :virsh_network      => :settings,
        :foreman_url        => :settings,
        :settings_directory => :settings,
        :http_port          => :settings,
        :https_port         => :settings,
        :use_cache          => :settings,
        :cache_location     => :settings,
        :puppetca_use_sudo  => :puppetca,
        :puppetdir          => :puppetca,
        :ssldir             => :puppetca,
        :sudo_command       => :puppetca,
        :customrun_args     => :puppet,
        :customrun_cmd      => :puppet,
        :freeipa_remove_dns => :realm
    }
  end

  def migrate_monolithic_config(data)
    output     = {}
    modules.each {|m| output[m] = {} }

    # chef's enabler got called something non-standard...
    data[:chef] = data.delete(:chefproxy) unless data[:chefproxy].nil?

    data.each do |option, value|
      parsed = false

      # handle special cases first
      if known_options.include? option
        m = known_options[option]
        output[m][option] = value
        data.delete(option)
        parsed = true
      end
      next if parsed

      if modules.include? option
        # Top level on/off option
        output[option][:enabled] = value
        data.delete(option)
      else
        modules.each do |mod|
          next unless option.to_s =~ /^#{mod.to_s}/
          output[mod][option] = value
          data.delete(option)
        end
      end
    end

    # Rename the port to whichever is correct
    if output[:settings].keys.include?(:port)
      if output[:settings].keys.include?(:ssl_certificate)
        output[:settings][:https_port] = output[:settings].delete(:port)
      else
        output[:settings][:http_port] = output[:settings].delete(:port)
      end
    end

    return output, data
  end

  def write_to_files(output,unknown)
    modules.each do |m|
      next if output[m] == {}
      filepath = m == :settings ? File.join(dst_dir, "settings.yml") : path(dst_dir, "settings.d", "#{m}.yml")
      File.open(filepath,'w') do |f|
        f.write(output[m].to_yaml)
        if m == :settings && unknown != {}
          f.write "\n# Unparsed options, please review\n"
          f.write(unknown.to_yaml.gsub(/^---/,''))
        end
      end
    end
  end
end