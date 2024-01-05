group :dhcp_isc do
  gem 'rb-inotify', install_if: -> { RUBY_PLATFORM.match?(/linux/) }
  gem 'rb-kqueue', install_if: -> { RUBY_PLATFORM.match?(/bsd/) }
  gem 'rsec', '< 1', platforms: [:ruby]
end
