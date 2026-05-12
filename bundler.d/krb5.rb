group :krb5 do
  gem 'rkerberos', '>= 0.1.1'
  gem 'gssapi'
end

tests = %w[dns realm]
ENV['SKIP_TEST_FILES'] = ((ENV['SKIP_TEST_FILES'] || "").split(",") + tests).uniq.join(",")
