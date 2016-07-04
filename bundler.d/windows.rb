group :windows do
  gem 'highline', :platforms => [:mingw, :x64_mingw]
  gem 'win32-service', :platforms => [:mingw, :x64_mingw]
  gem 'dhcpsapi', '~> 0.0'
end
