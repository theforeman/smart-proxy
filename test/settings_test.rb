require 'test_helper'

class SettingsTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    settings = Settings.load({})
    [Proxy::DNS::DefaultSettings::DEFAULTS, Proxy::Puppet::DefaultSettings::DEFAULTS].each do |defaults|
      defaults.each_pair { |k, v| assert settings.send(k) == v, "failed 'settings.#{k}' == '#{v}'" }
    end
  end

  def test_user_values_override_default_ones
    settings = Settings.load({ :dns_provider => 'test' })
    assert settings.dns_provider == 'test'
  end
end
