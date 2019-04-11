require 'yaml'

class MigratePuppetCaSettings < ::Proxy::Migration
  def migrate
    copy_original_configuration_except(path('settings.d', 'puppetca.yml'),
                                       path('settings.d', 'puppetca_puppet_cert.yml.example'))

    module_settings   = YAML.load_file(path(src_dir, 'settings.d', 'puppetca.yml'))
    if File.exist?(path(src_dir, 'settings.d', 'puppetca_puppet_cert.yml'))
      provider_settings = YAML.load_file(path(src_dir, 'settings.d', 'puppetca_puppet_cert.yml'))
    else
      provider_settings =  {}
    end

    write_yaml(path(dst_dir, 'settings.d', 'puppetca_puppet_cert.yml'),
               transform_provider_yaml(module_settings, provider_settings))
    write_yaml(path(dst_dir, 'settings.d', 'puppetca.yml'), transform_puppetca_yaml(module_settings))
  end

  def transform_puppetca_yaml(input)
    settings_moved_to_provider.each do |setting|
      input.delete(setting)
    end
    input
  end

  def transform_provider_yaml(module_settings, provider_settings)
    provider_settings = {} unless provider_settings.is_a? Hash
    settings_moved_to_provider.each do |setting|
      provider_settings[setting] = module_settings[setting]
    end
    provider_settings
  end

  def write_yaml(filepath, yaml)
    File.open(filepath, 'w') do |f|
      f.write(yaml.to_yaml)
    end
  end

  def settings_moved_to_provider
    [
      :ssldir,
      :puppetca_use_sudo,
      :sudo_command
    ]
  end
end
