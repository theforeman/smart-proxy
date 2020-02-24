require 'rsec'

module Proxy
  module DHCP
    module CommonISC
      class ConfigurationParser
        include Rsec::Helpers
        extend Rsec::Helpers

        FAR_FUTURE = Time.at(0x7fffffff).utc # max time value on 32-bit systems

        class Base
          attr_reader :parent, :dhcp_options, :node_attributes

          def initialize(parent)
            @parent = parent
            @dhcp_options = []
            @node_attributes = {}
          end

          def dhcp_options
            @dhcp_options ||= parent.nil? ? dhcp_options : parent.dhcp_options + dhcp_options
          end

          def parents
            parent.nil? ? [] : parent.parents
          end
        end

        class Host < Base
          attr_reader :name

          def initialize(parent, name)
            @name = name
            super(parent)
          end

          def parents
            super + ["host: #{name}"]
          end
        end

        class Lease < Base
          attr_reader :ip_address

          def initialize(parent, ip_address)
            @ip_address = ip_address
            super(parent)
          end

          def parents
            super + ["lease: #{ip_address}"]
          end
        end

        class Ipv4Subnet < Base
          attr_reader :subnet_address, :subnet_mask
          def initialize(parent, subnet_address, subnet_mask)
            @subnet_address = subnet_address
            @subnet_mask = subnet_mask
            super(parent)
          end

          def parents
            super + ["subnet: #{subnet_address}/#{subnet_mask}"]
          end
        end

        class Group < Base
          attr_reader :name
          def initialize(name, parent)
            @name = name
            super(parent)
          end

          def parents
            super + ["group: #{name}"]
          end
        end

        class Ignored < Base
          attr_reader :content
          def initialize(content, parent)
            @content = content
            super(parent)
          end
        end

        # rubocop:disable Style/StructInheritance
        class GroupNode < Struct.new :name, :options_and_settings
          def visit(all_hosts, all_subnets, all_ignored, parent)
            group = Group.new(name, parent)
            options_and_settings.flatten.each {|option_or_setting| option_or_setting.visit(all_hosts, all_subnets, all_ignored, group)}
          end
        end

        class IpV4SubnetNode < Struct.new :subnet_address, :subnet_mask, :options_and_settings
          def visit(all_hosts, all_subnets, all_ignored, parent)
            subnet = Ipv4Subnet.new(parent, subnet_address, subnet_mask)
            options_and_settings.flatten.each {|option_or_setting| option_or_setting.visit(all_hosts, all_subnets, all_ignored, subnet)}
            all_subnets.push(subnet)
          end
        end

        class OptionNode < Struct.new :should_supersede, :name, :params
          def visit(_, _, _, parent)
            parent.dhcp_options.push([name, params, should_supersede])
          end
        end

        class HostNode < Struct.new :fqdn, :options_and_settings
          def visit(all_hosts, _, all_ignored, parent)
            host = Host.new(parent, fqdn)
            options_and_settings.each {|option_or_setting| option_or_setting.visit([], [], all_ignored, host)}
            all_hosts.push(host)
          end
        end

        class LeaseNode < Struct.new :ip_address, :options_and_settings
          def visit(all_hosts, _, all_ignored, parent)
            lease = Lease.new(parent, ip_address)
            options_and_settings.each {|option_or_setting| option_or_setting.visit([], [], all_ignored, lease)}
            all_hosts.push(lease)
          end
        end

        class RangeNode < Struct.new :ip_addr_one, :ip_addr_two, :dynamic_bootp
          def visit(_, _, _, parent)
            parent.node_attributes[:range] = [ip_addr_one, ip_addr_two.nil? ? ip_addr_one : ip_addr_two] # range can contain one address only
          end
        end

        class IgnoredDeclaration < Struct.new :content
          def visit(all_hosts, all_subnets, all_ignored, parent)
            all_ignored.push(Ignored.new(content.join(' ').to_s, parent))
          end
        end

        class IgnoredBlock < Struct.new :declaration, :content
          def visit(all_hosts, all_subnets, all_ignored, parent)
            all_ignored.push(Ignored.new(declaration.join.to_s, parent))
          end
        end

        class HardwareNode < Struct.new :type, :address
          def visit(_, _, _, parent)
            parent.node_attributes[:hardware_type] = type
            parent.node_attributes[:hardware_address] = address
          end
        end

        class CommentNode < Struct.new :comment
          def visit(_, _, _, _); end
        end

        class KeyValueNode < Struct.new :key, :value
          def visit(_, _, _, parent)
            parent.node_attributes[key] = value
          end
        end

        class VendorOptionSpaceNode < Struct.new :value
          def visit(_, _, _, parent)
            # b/c the original implementation cared about SUNW namespace and no other namespaces
            # there's no other reason to care about this
            parent.node_attributes[:vendor_option_space] = 'SUNW' if value == 'SUNW'
          end
        end
        # rubocop:enable Style/StructInheritance

        class Literal < Rsec::Binary
          def _parse ctx
            buffer = StringIO.new
            bs = false
            end_of_string = false
            double_quote_counter = 0

            return Rsec::INVALID if ctx.peek(1) != '"'
            until end_of_string
              return Rsec::INVALID if ctx.eos?
              c = ctx.get_byte
              if bs
                buffer << sprintf("\\%c", c)
                bs = false
              elsif c == '\\'
                bs = true
              elsif c == '"'
                double_quote_counter += 1
                end_of_string = (double_quote_counter == 2)
                buffer << c
              else
                buffer << c
              end
            end

            buffer.string
          end
        end

        def literal &p
          Literal.new.map p
        end

        NBSP = /[\ \t]+/.r
        SPACE = /\s*/.r
        COMMENT = /#.*/.r.^('\n') {|comment| CommentNode[comment]}
        EOSTMT = ';'.r 'end of statement'
        COMMA =  /\s*,\s*/.r 'comma'
        HEX = /([a-fA-F0-9][a-fA-F0-9]?:)+[a-fA-F0-9][a-fA-F0-9]?/.r
        MAC_ADDRESS = /([a-fA-F0-9][a-fA-F0-9]?:){5}[a-fA-F0-9][a-fA-F0-9]?/.r 'EUI-48 mac address'
        MAC64_ADDRESS = /([a-fA-F0-9][a-fA-F0-9]?:){7}[a-fA-F0-9][a-fA-F0-9]?/.r 'EUI-64 mac address'
        MACIB_ADDRESS = /([a-fA-F0-9][a-fA-F0-9]?:){19}[a-fA-F0-9][a-fA-F0-9]?/.r 'infiniband mac address'
        IPV4_ADDRESS = /\d+\.\d+\.\d+\.\d+/.r 'ipv4 address'
        IPV4_ADDRESS_LIST = IPV4_ADDRESS.join(COMMA).even
        IPV6_ADDRESS = /[a-fA-F0-9:]+/.r 'ipv6 address'
        IPV6_ADDRESS_LIST = IPV6_ADDRESS.join(COMMA).even
        FQDN = /[a-zA-Z0-9\.-]+/.r 'host name'
        FQDN_LIST = FQDN.join(COMMA).even
        LFT_BRACKET = '{'.r 'left bracket'
        RGT_BRACKET = '}'.r  'right bracket'
        DOUBLE_QUOTE = '"'.r 'double quote'

        def ignored_declaration
          seq_(SPACE.join(/[^\s{};#]+/).odd, EOSTMT | COMMENT) {|content, _| IgnoredDeclaration[content]}
        end

        def ignored_block
          seq_(SPACE.join(/[^\s{};#]/).odd, LFT_BRACKET, SPACE.join(ignored_declaration | lazy {ignored_block}).odd, RGT_BRACKET) {|declaration, _, statements, _| IgnoredBlock[declaration, statements]}
        end

        def deleted
          Rsec::Fail.reset
          keyword = word('deleted').fail 'keyword_deleted'
          seq_(keyword, EOSTMT) {|_, _| KeyValueNode[:deleted, true]}
        end

        def option_values
          anything = /[^;,{}\s]+/.r
          SPACE.join(literal | anything).odd.join(COMMA).even
        end

        def server_duid
          Rsec::Fail.reset
          keyword = word('server-duid').fail 'keyword_server_duid'
          anything = /[^;,{}\s]+/.r
          llt = seq_(word('llt') | word('LLT'), SPACE.join(anything).odd._?)
          ll = seq_(word('ll') | word('LL'), SPACE.join(anything).odd._?)
          en = seq_(word('en') | word('EN'), prim(:int32), literal)
          seq_(keyword,  literal | HEX | en | llt | ll | prim(:int32), EOSTMT) {|_, duid, _| KeyValueNode[:server_duid, duid.respond_to?(:flatten) ? duid.flatten : duid]}
        end

        def filename
          Rsec::Fail.reset
          keyword = word('filename').fail 'keyword_filename'
          seq_(keyword, option_values, EOSTMT) {|_, values, _| OptionNode[false, 'filename', values]}
        end

        def next_server
          Rsec::Fail.reset
          keyword = word('next-server').fail 'keyword_next_server'
          seq_(keyword, option_values, EOSTMT) {|_, values, _| OptionNode[false, 'next-server', values]}
        end

        def vendor_option_space
          Rsec::Fail.reset
          keyword = word('vendor-option-space').fail 'keyword_vendor_option_space'
          anything = /[^;,{}\s]+/.r
          seq_(keyword, anything, EOSTMT) {|_, value, _| VendorOptionSpaceNode[value]}
        end

        def option
          Rsec::Fail.reset
          keyword_option = word('option').fail 'keyword_option'
          keyword_code = /code \d+/.r 'keyword_code'
          keyword_supersede = word('supersede').fail 'keyword_supersede'
          option_name = /[\w\.-]+/.r
          seq_(keyword_option | keyword_supersede, option_name, keyword_code._?, '='.r._?, LFT_BRACKET._?, option_values, RGT_BRACKET._?, EOSTMT) do |maybe_supersede, name, _, _, _, values, _, _|
            OptionNode[maybe_supersede == 'supersede', name, values]
          end | vendor_option_space | filename | next_server
        end

        def set
          Rsec::Fail.reset
          keyword_set = word('set').fail 'keyword_set'
          seq_(keyword_set, /[\w\.-]+/.r, '='.r._?, literal, EOSTMT) {|_, iname, _, ivalue, _| IgnoredDeclaration[["#{iname}=#{ivalue}"]]}
        end

        # used in host and lease blocks
        def hardware
          Rsec::Fail.reset
          hardware_keyword = word('hardware').fail 'keyword_hardware'
          ethernet_keyword = word('ethernet').fail 'keyword_ethernet'
          token_ring_keyword = word('token-ring').fail 'keyword_token_ring'
          seq_(hardware_keyword, ethernet_keyword | token_ring_keyword, MACIB_ADDRESS | MAC64_ADDRESS | MAC_ADDRESS, EOSTMT) {|_, type, address, _| HardwareNode[type, address]}
        end

        def fixed_address
          Rsec::Fail.reset
          keyword = word('fixed-address').fail 'keyword_fixed_address'
          seq_(keyword, IPV4_ADDRESS | FQDN, EOSTMT) {|_, address| KeyValueNode[:fixed_address, address]}
        end

        def dynamic
          Rsec::Fail.reset
          keyword_dynamic = word('dynamic').fail 'keyword_dynamic'
          seq_(keyword_dynamic, EOSTMT) {|_, _| KeyValueNode[:dynamic, true]}
        end

        def host
          Rsec::Fail.reset
          keyword_host = word('host').fail 'keyword_host'
          seq_(keyword_host, FQDN, LFT_BRACKET,
               SPACE.join(option | hardware | fixed_address | COMMENT | deleted | dynamic | ignored_declaration | ignored_block).odd,
               SPACE._?, RGT_BRACKET) {|_, fqdn, _, statements, _| HostNode[fqdn, statements]}
        end

        def lease_time_stamp
          Rsec::Fail.reset
          db_time = /\d\s+[\d\/]+\s+[\d:]+/.r {|t| Time.parse(t + " UTC")} # db-time is UTC
          local_time = seq_(word('epoch'), prim(:unsigned_int64)) {|_, t| Time.at(t).utc} # since epoch
          never = word('never') {|_| FAR_FUTURE}

          starts_keyword = word('starts')
          ends_keyword = word('ends')
          tstp_keyword = word('tstp')
          tsfp_keyword = word('tsfp')
          atsfp_keyword = word('atsfp')
          cltt_keyword = word('cltt')

          seq_(starts_keyword | ends_keyword | tstp_keyword | tsfp_keyword | atsfp_keyword | cltt_keyword, db_time | local_time | never, EOSTMT) {|type, value, _| KeyValueNode[type.to_sym, value]}
        end

        def lease_binding_state
          Rsec::Fail.reset
          state_matcher = /\w+/.r
          binding_state_keyword = word('binding state').fail 'keyword_binding_state'
          next_binding_state_keyword = word('next binding state').fail 'keyword_next_binding_state'

          seq_(binding_state_keyword | next_binding_state_keyword, state_matcher, EOSTMT) {|state, value| KeyValueNode[state.tr(' ', '_').to_sym, value]}
        end

        def lease_uid
          keyword = word('uid').fail 'keyword_uid'
          seq_(keyword, literal, EOSTMT) {|_, value, _| KeyValueNode[:uid, value]}
        end

        def lease_hostname
          keyword = word('client-hostname').fail 'keyword_client_hostname'
          seq_(keyword, literal | FQDN, EOSTMT) {|_, fqdn, _| KeyValueNode[:client_hostname, fqdn]}
        end

        def lease
          Rsec::Fail.reset
          keyword = word('lease').fail 'keyword_lease'
          seq_(keyword, IPV4_ADDRESS, LFT_BRACKET,
               SPACE.join(option | hardware | lease_time_stamp | lease_binding_state | lease_uid | lease_hostname | set | COMMENT | ignored_declaration | ignored_block).odd,
               SPACE._?, RGT_BRACKET) {|_, ip, _, statements, _| LeaseNode[ip, statements]}
        end

        def range
          Rsec::Fail.reset
          range_keyword = word('range').fail 'keyword_range'
          bootp_keyword = word('dynamic-bootp').fail 'keyword_dynamic-bootp'
          seq_(range_keyword, bootp_keyword._?, IPV4_ADDRESS, IPV4_ADDRESS._?, EOSTMT) do |_, bootp, ip_addr_one, ip_addr_two, _|
            RangeNode[ip_addr_one, ip_addr_two.first, !bootp.empty?]
          end
        end

        def group
          Rsec::Fail.reset
          keyword = word('group').fail 'keyword_group'
          anything = /[^;,{}\s]+/.r
          seq_(keyword, SPACE.join(literal | anything).odd._?, LFT_BRACKET,
               SPACE.join(option | host | lazy {subnet} | lazy {group} | lazy {shared_network} | COMMENT | deleted | ignored_declaration | ignored_block).odd,
               RGT_BRACKET).cached {|_, name, _, statements, _| GroupNode[name.flatten.first, statements]}
        end

        def shared_network
          Rsec::Fail.reset
          keyword = word('shared-network').fail 'keyword_shared_network'
          seq_(keyword,
               SPACE.join(literal | FQDN).odd, LFT_BRACKET,
               SPACE.join(include_file | option | host | lazy {subnet} | lazy {group} | pool | COMMENT | deleted | ignored_declaration | ignored_block).odd,
               RGT_BRACKET).cached {|_, name, _, statements, _| GroupNode[name.first, statements]}
        end

        def pool
          Rsec::Fail.reset
          keyword = word('pool').fail 'keyword_pool'
          seq_(keyword, LFT_BRACKET, SPACE.join(range | option | host | COMMENT | ignored_declaration | ignored_block).odd, RGT_BRACKET) {|_, _, statements, _| GroupNode["pool", statements]}
        end

        def subnet
          Rsec::Fail.reset
          subnet_keyword = word('subnet').fail 'keyword_subnet'
          netmask_keyword = word('netmask').fail 'keyword_netmask'

          seq_(
            subnet_keyword, IPV4_ADDRESS, netmask_keyword, IPV4_ADDRESS,
            LFT_BRACKET, SPACE.join(range | option | host | lazy {group} | pool | COMMENT | ignored_declaration | ignored_block).odd,
            RGT_BRACKET).cached do |_, subnet_address, _, subnet_mask, _, statements, _|
            IpV4SubnetNode[subnet_address, subnet_mask, statements]
          end
        end

        def include_file
          Rsec::Fail.reset
          include_keyword = word('include').fail 'include_keyword'
          seq_(include_keyword, literal) do |_, filename_in_quotes|
            parse_file(literal_to_filename(filename_in_quotes))
          end
        end

        def literal_to_filename(a_literal)
          a_literal[1..-2]
        end

        def conf(config_basedir = nil)
          @config_basedir = config_basedir
          SPACE.join(option | host | lease | group | subnet | shared_network | include_file | COMMENT | server_duid | ignored_declaration | ignored_block | EOSTMT).odd.eof
        end

        def start_visiting_parse_tree_nodes(parse_tree)
          all_hosts = []
          all_subnets = []
          all_ignored = []
          root = Group.new("root_group", nil)

          visit_parse_tree_nodes(parse_tree, all_hosts, all_subnets, all_ignored, root)

          [all_subnets, all_hosts, root, all_ignored]
        end

        def visit_parse_tree_nodes(parse_tree, all_hosts, all_subnets, all_ignored, root)
          parse_tree.each do |node|
            node.is_a?(Array) ? visit_parse_tree_nodes(node, all_hosts, all_subnets, all_ignored, root) : node.visit(all_hosts, all_subnets, all_ignored, root)
          end
        end

        def parse_file(a_path)
          a_path = File.absolute_path(a_path, @config_basedir) unless @config_basedir.nil?
          File.open(a_path, 'r:ASCII-8BIT') {|f| conf.parse!(f.read, a_path)}
        end

        # returns all_subnets, all_hosts, root_group
        def subnets_hosts_and_leases(conf_as_string, filename)
          config_basedir = File.dirname(filename)
          parsed = conf(config_basedir).parse!(conf_as_string, filename)
          start_visiting_parse_tree_nodes(parsed)
        end
      end
    end
  end
end
