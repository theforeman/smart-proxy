require 'English'

begin
  require "ci/reporter/rake/test_unit"
  namespace :jenkins do
    task :unit => ["jenkins:setup:test_unit", 'rake:test']

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
        --format progress \
        --format RuboCop::Formatter::CheckstyleFormatter \
        --no-color --out rubocop.xml")
      exit($CHILD_STATUS.exitstatus)
    end
  end
rescue LoadError
  # ci/reporter/rake/rspec not present, skipping this definition
end
