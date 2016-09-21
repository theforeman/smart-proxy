group :puppet_proxy_legacy do
  gem 'json_pure', '< 2.0.0', :require => false if RUBY_VERSION < '2.0.0'
  gem 'puppet', '< 5.0.0'
  gem 'ruby-augeas', :require => 'augeas'
end

group :puppet_proxy_puppet_api do
  gem 'concurrent-ruby', '~> 1.0'
end
