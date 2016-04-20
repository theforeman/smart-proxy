module Proxy::DHCP
  module ISC
    class LeasesFile
      attr_reader :path, :parser, :fd

      def initialize(a_path, config_and_leases_parser)
        @path = a_path
        @parser = config_and_leases_parser
      end

      def hosts_and_leases
        @fd = File.open(File.expand_path(path), "r") if fd.nil?
        parser.parse_config_and_leases_for_records(fd.read)
      end

      def close
        return if fd.nil?
        fd.close
        @fd = nil
      end
    end
  end
end
