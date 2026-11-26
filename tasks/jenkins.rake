namespace :jenkins do
  desc 'Sets up CI environment for testing and run tests'
  task :unit => :test
end
