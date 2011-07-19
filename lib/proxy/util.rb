require 'open3'

module Proxy::Util

  class CommandTask
    include Proxy::Log

    # track all threads in the class variable
    @@tasks = []

    # create new task and spawn new thread logging all the cmd
    # output to the proxy log. only the process' output is connected
    # stderr is redirected to proxy error log, stdout to proxy debug log
    def initialize(cmd)
      # clean finished tasks from the array
      @@tasks = @@tasks.collect { |t| nil unless t.is_a? String }.compact

      # run the task in its own thread
      logger.debug "Starting task (total: #{@@tasks.size}): #{cmd}"
      @task = Thread.new(cmd) do |cmd|
        Open3::popen3(cmd) do |stdin,stdout,stderr,thr|
          # PIDs are not available under Ruby 1.8
          pid = thr.nil? ? rand(9999) : thr.pid
          stdout.each do |line|
            logger.debug "[#{pid}] #{line}"
          end
          stderr.each do |line|
            logger.error "[#{pid}] #{line}"
          end
        end
        $?
      end
      @@tasks << @task
    end

    # wait for the task to finish and get the subprocess return code
    def join
      @task.value
    end

    # wait for all tasks to finish
    def self.join_all
      @@tasks.each { |aThread| aThread.join }
    end
  end

  # searches for binaries in predefined directories and user PATH
  # accepts a binary name and an array of paths to search first
  # if path is omitted will search only in user PATH
  def which(bin, *path)
    path += ENV['PATH'].split(File::PATH_SEPARATOR)
    path.flatten.uniq.each do |dir|
      dest = File.join(dir, bin)
      return dest if FileTest.file? dest and FileTest.executable? dest
    end
    return false
  rescue StandardError => e
    logger.warn e
    return false
  end
end
