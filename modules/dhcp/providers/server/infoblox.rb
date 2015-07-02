require 'dhcp/subnet'
require 'dhcp/record'
require 'dhcp/record/reservation'
require 'dhcp/server'
require 'infoblox'

module Proxy::DHCP
  # Represents Infoblox DHCP Server (https://www.infoblox.com) uses https://github.com/govdelivery/infoblox >= 0.4.1
  class Infoblox < Server
    def initialize(options = {})
      super options[:server]
      @username = options[:username]
      @password = options[:password]
    end

   def connect
     ::Infoblox::Connection.new(:username => Proxy::DhcpPlugin.settings.username, :password => Proxy::DhcpPlugin.settings.password, :host => Proxy::DhcpPlugin.settings.dhcp_server)
   end

   def delRecord subnet, record
     validate_subnet subnet
     validate_record record
     # TODO: Refactor this into the base class
     raise InvalidRecord, "#{record} is static - unable to delete" unless record.deleteable?
     # "Deleting"" a record here means just disabling dhcp
     connection = connect
     host = ::Infoblox::Host.find(connection, "ipv4addr" => record.ip)
     unless host.empty?
       # if not empty, first element is what we want to edit
       host = host.first
       # Select correct ipv4addr object from ipv4addrs array
       hostip = host.ipv4addrs.find { |ip| ip.ipv4addr == record.ip }
       hostip.configure_for_dhcp = false
       # Send object
       host.put
     end
     subnet.delete(record)
   end

    def addRecord options={}
      logger.debug "Add Record"
      record = super(options)
      
      connection = connect
      host = ::Infoblox::Host.find(connection, "ipv4addr" => record.ip)
      # If empty create:
      if host.empty?
        logger.debug "Add Record - Create"
        # Create new host object
        host = ::Infoblox::Host.new(:connection => connection)
        host.name = record.name
        host.add_ipv4addr(record.ip)
        post = true
      else
        logger.debug "Add Record - Exists using first element"
        # if not empty, first element is what we want to edit
        host = host.first
        post = false
      end
      options = record.options
      # Overwrite values without checking
      # Select correct ipv4addr object from ipv4addrs array
      hostip = host.ipv4addrs.find { |ip| ip.ipv4addr == record.ip }
      logger.debug "Add Record - record.name: #{record.name}, hostip.host #{hostip.host}, record.mac #{record.mac}, record.ip #{record.ip}"
      logger.debug "Add Record - options[:nextServer] #{options[:nextServer]}, options[:filename] #{options[:filename]}, hostip.ipv4addr: #{hostip.ipv4addr} "
      raise InvalidRecord, "#{record} Hostname mismatch" unless hostip.host == record.name
      hostip.mac = record.mac
      hostip.configure_for_dhcp = true
      hostip.nextserver = options[:nextServer]
      hostip.use_nextserver = true
      hostip.bootfile = options[:filename]
      hostip.use_bootfile = true
      ## Test if Host Entry has correct IP
      raise InvalidRecord, "#{record} IP mismatch" unless hostip.ipv4addr == record.ip
      # Send object
      post ? host.post : host.put
      record
    end
    
    def find_record(record)
      logger.debug "loadRecord"
      connection = connect
      # if record is a String it can be either ip or mac, true = mac --> lookup ip
      if record.is_a?(String) && (IPAddr.new(record) rescue nil).nil?
        hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "mac" => record).first
        ipv4address = hostdhcp.ipv4addr
      elsif record.is_a?(String)
        ipv4address = record
      end
      ipv4address = record[:ip] if record.is_a?(Proxy::DHCP::Record)
      ipv4address = record.to_s if record.is_a?(IPAddr)
      host = ::Infoblox::Host.find(connection, "ipv4addr" => ipv4address).first
      return nil if host.nil? || host.name.empty?
      hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "ipv4addr" => ipv4address).first
      return nil unless hostdhcp.configure_for_dhcp
      return nil if hostdhcp.mac.empty? || hostdhcp.ipv4addr.empty?
      opts = {:hostname => host.name}
      opts[:mac] = hostdhcp.mac
      opts[:ip] = hostdhcp.ipv4addr
      opts[:deleteable] = true
      opts[:nextServer] = hostdhcp.nextserver if hostdhcp.use_nextserver
      opts[:filename] = hostdhcp.bootfile if hostdhcp.use_bootfile
      # Subnet should only be one, not checking that yet
      subnet = subnets.find { |s| s.include? ipv4address}
      Proxy::DHCP::Record.new(opts.merge(:subnet => subnet))
    end

    def loadSubnetData subnet
      # Load network from infoblox, iterate over ips to gather additional settings
      logger.debug "LoadSubnetData"
      super
      network = IPAddr.new(subnet.to_s, Socket::AF_INET)
      connection = connect
      # max results are currently set to work in my setup, one could calculate that setting by looking at netmask :)
      network = ::Infoblox::Ipv4address.find(connection, "network" => "#{network}/#{subnet.cidr}", "_max_results" => "2500")
      # Find out which hosts are in use
      network.each do |host|
        # next if certain values are not set
        next if host.names.empty? || host.mac_address.empty? || host.ip_address.empty?
        hostdhcp = ::Infoblox::HostIpv4addr.find(connection, "ipv4addr" => host.ip_address).first
        next unless hostdhcp.configure_for_dhcp
        opts = {:hostname => host.names.first}
        opts[:mac] = host.mac_address
        opts[:ip] = host.ip_address
        # broadcast and network entrys are not deleteable
        opts[:deleteable] = true unless (host.types & ['BROADCAST', 'NETWORK']).any?
        opts[:nextServer] = hostdhcp.nextserver unless hostdhcp.use_nextserver
        opts[:filename] = hostdhcp.bootfile unless hostdhcp.use_bootfile
        Proxy::DHCP::Reservation.new(opts.merge(:subnet => subnet))
      end
    end

    private
    def loadSubnets
      super
      connection = connect
      ::Infoblox::Network.all(connection).each do |obj|
        if match = obj.network.split('/')
          tmp = IPAddr.new(obj.network)
          netmask = IPAddr.new(tmp.instance_variable_get("@mask_addr"), Socket::AF_INET).to_s
          next unless managed_subnet? "#{match[0]}/#{netmask}"
          Proxy::DHCP::Subnet.new(self, match[0], netmask)
        end
      end
    end
    
  end
end
