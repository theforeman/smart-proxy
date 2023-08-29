require "ci/reporter/rake/test_unit"
namespace :jenkins do
  desc 'Sets up CI environment for testing and run tests'
  task :unit => ['ci:setup:testunit', 'rake:test']
end
