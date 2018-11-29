group :puppet_proxy_legacy do
  gem 'puppet', ENV.key?('PUPPET_VERSION') ? "~> #{ENV['PUPPET_VERSION']}" : '< 6.0.0'
  gem 'ruby-augeas', :require => 'augeas'
end
