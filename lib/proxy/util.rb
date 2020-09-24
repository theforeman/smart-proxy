require 'English'
require 'open3'
require 'shellwords'
require 'base64'

module Proxy::Util
  class CommandTask
    include Proxy::Log
    attr_reader :command

    # create new task and spawn new thread logging all the cmd
    # output to the proxy log. only the process' output is connected
    # stderr is redirected to proxy error log, stdout to proxy debug log
    # command can be either string or array (command + arguments)
    # input is passed into STDIN and must be string
    def initialize(command, input = nil)
      @command = command
      @input = input
    end

    def start(&ensured_block)
      # run the task in its own thread
      @task = Thread.new(@command, @input) do |cmd, input|
        status = nil
        Open3.popen3(*cmd) do |stdin, stdout, stderr, thr|
          logger.info "[#{thr.pid}] Started task #{cmd}"
          stdin.write(input) if input
          stdin.close
          stdout.each do |line|
            logger.debug "[#{thr.pid}] #{line}"
          end
          stderr.each do |line|
            logger.warn "[#{thr.pid}] #{line}"
          end
          # call thr.value to wait for a Process::Status object.
          status = thr.value
        end
        status ? status.exitstatus : $CHILD_STATUS
      ensure
        yield if block_given?
      end
      self
    end

    # wait for the task to finish and get the subprocess return code
    def join
      @task.value
    end
  end

  # convert setting to boolean (with a default value)
  def to_bool(value, default = false)
    return default if value.nil?
    return value if value.is_a?(TrueClass) || value.is_a?(FalseClass)
    !!(value =~ /^(true|t|yes|y|1)$/i)
  end

  # searches for binaries in predefined directories and user PATH
  # accepts a binary name and an array of paths to search first
  # if path is omitted will search only in user PATH
  def which(bin, *path)
    path += ['/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin']
    path += ENV['PATH'].split(File::PATH_SEPARATOR)
    path.flatten.uniq.each do |dir|
      dest = File.join(dir, bin)
      return dest if FileTest.file?(dest) && FileTest.executable?(dest)
    end
    false
  rescue StandardError => e
    logger.warn e
    false
  end

  def escape_for_shell(command)
    Shellwords.escape(command)
  end

  def shell_command(cmd, wait = true)
    begin
      c = popen(cmd)
      unless wait
        Process.detach(c.pid)
        return 0
      end
      Process.wait(c.pid)
    rescue Exception => e
      logger.error "Error when executing '#{cmd}'", e
      return false
    end
    logger.warn("Non-null exit code when executing '#{cmd}'") if $CHILD_STATUS.exitstatus != 0
    $CHILD_STATUS.exitstatus == 0
  end

  def popen(cmd)
    logger.debug("about to execute: #{cmd}")
    IO.popen(cmd)
  end

  def strict_encode64(str)
    if Base64.respond_to?(:strict_encode64)
      Base64.strict_encode64(str)
    else
      Base64.encode64(str).delete("\n")
    end
  end

  def hash_to_query_string(input = {})
    input.compact.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v)}" }.join("&")
  end
end
