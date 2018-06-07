group :puppetca_token_whitelisting do
  if RUBY_VERSION < '2.1'
    gem 'jwt', '~> 1.5.6'
  else
    gem 'jwt'
  end
end
