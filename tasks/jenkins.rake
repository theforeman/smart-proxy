begin
  testtool = RUBY_VERSION =~ /^1\.8/ ? 'test_unit' : 'minitest'
  require "ci/reporter/rake/#{testtool}"
  namespace :jenkins do
    task :unit => ["jenkins:setup:#{testtool}", 'rake:test']

    namespace :setup do
      task :pre_ci do
        ENV["CI_REPORTS"] = 'jenkins/reports/unit/'
        gem 'ci_reporter'
      end
      task :minitest  => [:pre_ci, "ci:setup:minitest"]
      task :test_unit => [:pre_ci, "ci:setup:testunit"]
    end

    task :rubocop do
      system("bundle exec rubocop \
        --require rubocop/formatter/checkstyle_formatter \
        --format RuboCop::Formatter::CheckstyleFormatter \
        --no-color --out rubocop.xml")
      exit($?.exitstatus)
    end
  end
rescue LoadError
  # ci/reporter/rake/rspec not present, skipping this definition
end

