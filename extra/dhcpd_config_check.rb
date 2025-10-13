$LOAD_PATH.unshift(*Dir[File.expand_path('../modules', __dir__)])

require 'English'
require 'optparse'
require 'dhcp_common/isc/configuration_parser'

class MissingOption < RuntimeError; end

def parse_cli_options(args)
  result = {}

  options_parser = OptionParser.new do |opts|
    opts.banner = "Usage: dhcpd_config_check.rb [options]"
    opts.separator ""

    opts.on('-c', '--config_file CFG_FILE_PATH', 'dhcpd configuration file path (read-only)') do |cfg_path|
      result[:cfg_path] = File.expand_path(cfg_path)
    end
  end

  options_parser.parse!(args)
  return result unless result[:cfg_path].nil?

  puts "missing option: -c"
  puts options_parser
  raise MissingOption
rescue OptionParser::MissingArgument, OptionParser::InvalidOption => e
  puts e
  puts options_parser
  raise e
end

if $PROGRAM_NAME == __FILE__
  begin
    options = parse_cli_options(ARGV)
    parser = Proxy::DHCP::CommonISC::ConfigurationParser.new
    subnets, hosts, _, ignored = parser.subnets_hosts_and_leases(File.read(options[:cfg_path]), options[:cfg_path])
    puts "Subnets: %s" % [subnets.map { |s| "#{s.subnet_address}/#{s.subnet_mask}" }.join(', ')]
    puts "Hosts and leases: %s" % [hosts.map { |h| h.respond_to?(:ip_address) ? "Lease: #{h.ip_address}" : "Host: #{h.name}" }.join(', ')]
    puts "Didn't recognize: \n%s" % [ignored.map { |i| "#{i.content}, parents: #{i.parents.join(', ')}" }.join("\n")]
  rescue OptionParser::InvalidOption, OptionParser:: MissingArgument, MissingOption
    exit(1)
  rescue RuntimeError => e
    p e
    exit(1)
  rescue Exception => e
    puts "Error parsing configuration file '%s': %s" % [options[:cfg_path], e.backtrace]
    exit(1)
  end

  puts "Successfully parsed configuration file '%s'" % [options[:cfg_path]]
  exit(0)
end
