class Proxy::PuppetCustomrun::Runner < Proxy::Puppet::Runner
  attr_reader :command, :command_arguments

  def initialize(command, arguments)
    @command = command
    @command_arguments = arguments.is_a?(Array) ? arguments : arguments.split(' ')
    super()
  end

  def run(nodes)
    unless File.exist?(command)
      logger.warn "#{command} not found."
      return false
    end

    shell_command(([escape_for_shell(command), command_arguments] + shell_escaped_nodes(nodes)).flatten)
  end
end
