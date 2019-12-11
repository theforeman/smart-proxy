group :dhcp_isc_inotify do
  gem 'rsec', '< 1'
  if RUBY_VERSION < '2.2'
    gem 'rb-inotify', '< 0.10'
  else
    gem 'rb-inotify'
  end
end

group :dhcp_isc_kqueue do
  gem 'rsec', '< 1'
  gem 'rb-kqueue'
end
