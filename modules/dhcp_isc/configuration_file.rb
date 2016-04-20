module Proxy::DHCP
  module ISC
    class ConfigurationFile
      attr_reader :path, :parser

      def initialize(a_path, config_and_leases_parser)
        @path = a_path
        @parser = config_and_leases_parser
      end

      def subnets
        File.open(File.expand_path(path), "r") {|f| parser.parse_config_for_subnets(read(f))}
      end

      def hosts_and_leases
        File.open(File.expand_path(path), "r") {|f| parser.parse_config_and_leases_for_records(read(f))}
      end

      def read(a_fd)
        to_return = []
        a_fd.readlines.each do |line|
          line = line.split('#').first.strip # remove comments, left and right whitespace
          next if line.empty? # remove blank lines

          if /^include\s+"(.*)"\s*;.*/ =~ line
            conf = $1
            raise "Unable to find the included DHCP configuration file: #{conf}" unless File.exist?(conf)
            # concat modifies the receiver rather than creating a new array
            # and does not create a multidimensional array
            to_return.concat([File.open(conf, 'r') {|f| read(f)}])
          else
            to_return << line
          end
        end
        to_return.join("")
      end

      def close
        # do nothing, as the file is closed after every access
      end
    end
  end
end
