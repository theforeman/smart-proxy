require 'yaml'

class MigratePuppetCaSettings < ::Proxy::Migration
  def migrate
    copy_original_configuration_except(path('settings.d', 'puppetca.yml'),
                                       path('settings.d', 'puppetca_hostname_whitelisting.yml.example'))

    module_settings   = YAML.load_file(path(src_dir, 'settings.d', 'puppetca.yml'))
    provider_settings = YAML.load_file(path(src_dir, 'settings.d', 'puppetca_hostname_whitelisting.yml'))

    write_yaml(path(dst_dir, 'settings.d', 'puppetca_hostname_whitelisting.yml'),
               transform_provider_yaml(module_settings, provider_settings))
    write_yaml(path(dst_dir, 'settings.d', 'puppetca.yml'), transform_puppetca_yaml(module_settings))
  end

  def transform_puppetca_yaml(input)
    input.delete(:autosignfile)
    input[:use_provider] = 'puppetca_hostname_whitelisting'
    input
  end

  def transform_provider_yaml(module_settings, provider_settings)
    provider_settings = {} unless provider_settings.is_a? Hash
    provider_settings[:autosignfile] = module_settings[:autosignfile]
    provider_settings
  end

  def write_yaml(filepath, yaml)
    File.open(filepath, 'w') do |f|
      f.write(yaml.to_yaml)
    end
  end
end
