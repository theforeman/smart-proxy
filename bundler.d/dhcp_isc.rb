group :dhcp_isc_inotify do
  gem 'rsec', '< 1'
  gem 'rb-inotify'
end

group :dhcp_isc_kqueue do
  gem 'rsec', '< 1'
  gem 'rb-kqueue'
end
