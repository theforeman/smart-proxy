gem 'rsec', '< 1', groups: [:dhcp_isc_inotify, :dhcp_isc_kqueue]

group :dhcp_isc_inotify do
  gem 'rb-inotify'
end

group :dhcp_isc_kqueue do
  gem 'rb-kqueue'
end
