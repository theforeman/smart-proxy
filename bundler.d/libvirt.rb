group :libvirt do
  gem 'ruby-libvirt', '>= 0.6.0'
end

tests = %w[dhcp_libvirt dns_libvirt migrations/libvirt_migration_test.rb]
ENV['SKIP_TEST_FILES'] = ((ENV['SKIP_TEST_FILES'] || "").split(",") + tests).uniq.join(",")
