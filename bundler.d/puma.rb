group :puma do
  if RUBY_VERSION < '2.3'
    # Important!
    # The last actual version that supports v2.0.0 up to v2.2.0 is 3.10.0
    # Puma version 3.11.0 changed the usage of socket to a feature that is not
    # supported by Ruby 2.2.0 and lower, and it causes a crash on TLS!
    gem 'puma', '3.10.0', :require => 'puma'
  else
    gem 'puma', '~>3.12', :require => 'puma'
  end
end
