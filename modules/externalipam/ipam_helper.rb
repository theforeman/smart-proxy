require 'proxy/validations'
require 'externalipam/externalipam'

# Module containing helper methods for use by all External IPAM provider implementations
module Proxy::Ipam::IpamHelper
  include ::Proxy::Validations

  MAX_IP_RETRIES = 10
  ERRORS = {
    cidr: "A 'cidr' parameter for the subnet must be provided(e.g. IPv4: 100.10.10.0/24, IPv6: 2001:db8:abcd:12::/124)",
    mac: "A 'mac' address must be provided(e.g. 00:0a:95:9d:68:10)",
    ip: "Missing 'ip' parameter. An IPv4 or IPv6 address must be provided(e.g. IPv4: 100.10.10.22, IPv6: 2001:db8:abcd:12::3)",
    group_name: "A 'group_name' must be provided",
    no_ip: 'IP address not found',
    no_free_ips: 'No free addresses found',
    no_connection: 'Unable to connect to External IPAM server',
    no_group: 'Group not found in External IPAM',
    no_groups: 'No groups found in External IPAM',
    no_subnet: 'Subnet not found in External IPAM',
    no_subnets_in_group: 'No subnets found in External IPAM group',
    provider: "The IPAM provider must be specified(e.g. 'externalipam_phpipam' or 'externalipam_netbox')",
    groups_not_supported: 'Groups are not supported',
    add_ip: 'Error adding IP to External IPAM',
    bad_mac: 'Mac address is invalid',
    bad_ip: 'IP address is invalid',
    bad_cidr: 'The network cidr is invalid',
    proxy_validation_error: 'Proxy validation error',
    runtime_error: 'Runtime error',
  }.freeze

  def provider
    @provider ||=
      begin
        unless client.authenticated?
          halt 500, { error: 'Invalid credentials for External IPAM' }.to_json
        end
        client
      end
  end

  # Called when next available IP from External IPAM has been cached by another user/host, but
  # not actually persisted in External IPAM yet. This method will increment the IP, up to
  # MAX_IP_RETRIES times, and check if it is available in External IPAM each iteration. It
  # will return the original IP(the 'ip' param) if no new IP's are found after MAX_IP_RETRIES
  # iterations.
  def find_new_ip(ip_cache, subnet_id, ip, mac, cidr, group_name)
    found_ip = nil
    temp_ip = ip
    retry_count = 0

    while retry_count < MAX_IP_RETRIES
      new_ip = increment_ip(temp_ip)
      ipam_ip = ip_exists?(new_ip, subnet_id, group_name)

      # If new IP doesn't exist in IPAM and not in the cache
      if !ipam_ip && !ip_cache.ip_exists?(group_name, cidr, new_ip)
        found_ip = new_ip.to_s
        ip_cache.add(group_name, cidr, found_ip, mac)
        break
      end

      temp_ip = new_ip
      retry_count += 1
    end

    return ip if found_ip.nil?

    found_ip
  end

  # Checks the cache for existing ip, and returns it if it exists. If not exists, it will
  # find a new ip (using find_new_ip), and it is added to the cache.
  def cache_next_ip(ip_cache, ip, mac, cidr, subnet_id, group_name)
    group = group_name.nil? ? '' : group_name
    subnet_hash = ip_cache.get_cidr(group, cidr)
    next_ip = nil

    if mac && subnet_hash&.key?(mac)
      next_ip = ip_cache.get_ip(group, cidr, mac)
    else
      new_ip = ip
      ip_in_cache = ip_cache.ip_exists?(group, cidr, new_ip)
      ip_expired = ip_cache.ip_expired?(group, cidr, new_ip)

      if ip_in_cache && !ip_expired
        next_ip = find_new_ip(ip_cache, subnet_id, new_ip, mac, cidr, group)
      else
        next_ip = new_ip.to_s
        ip_cache.add(group, cidr, new_ip, mac)
      end

      halt 404, { error: "No free addresses found in subnet #{cidr}. Some available ip's may be cached. Try again in #{@ip_cache.cleanup_interval} seconds after cache is cleared." }.to_json unless usable_ip(next_ip, cidr)
    end

    next_ip
  end

  def increment_ip(ip)
    IPAddr.new(ip.to_s).succ.to_s
  end

  def usable_ip(ip, cidr)
    ip_addr = IPAddr.new(ip)
    return true if ip_addr.ipv6?
    network = IPAddr.new(cidr)
    network.include?(ip_addr) && network.to_range.last != ip && network.to_range.first != ip
  end

  def get_request_group(params)
    halt 500, { error: errors[:groups_not_supported] }.to_json if params[:group] && !provider.groups_supported?
    CGI.unescape(params[:group].to_s)
  end
end
