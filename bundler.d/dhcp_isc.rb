group :dhcp_isc do
  gem 'rsec', '< 1'

  install_if -> { RUBY_PLATFORM.match?(/linux/) } do
    gem 'rb-inotify'
  end
  install_if -> { RUBY_PLATFORM.match?(/bsd/) } do
    gem 'rb-kqueue'
  end
end
