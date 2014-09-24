require 'rubocop/rake_task'

desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ['bin/**/*.rb', 'lib/**/*.rb', 'modules/**/*.rb', 'extra/**/*.rb', 'test/**/*.rb', 'views/**/*.rb']
#  task.formatters = ['files']
  task.fail_on_error = false
end
