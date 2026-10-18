require 'yaml'
require 'externalipam/externalipam'
require 'externalipam/ipam_helper'
require 'externalipam/ipam_validator'
require 'externalipam/api_resource'
require 'externalipam/ip_cache'

module Proxy::Netbox
  # Implementation class for External IPAM provider Netbox
  class NetboxClient
    include Proxy::Log
    include Proxy::Ipam::IpamHelper
    include Proxy::Ipam::IpamValidator

    def initialize(conf)
      @api_base = "#{conf[:url]}/api/"
      @token = conf[:token]
      @api_resource = Proxy::Ipam::ApiResource.new(api_base: @api_base, token: "Token #{@token}")
      @ip_cache = Proxy::Ipam::IpCache.instance
      @ip_cache.provider_name('netbox')
    end

    def get_ipam_subnet(cidr, group_name = nil)
      if group_name.nil? || group_name.empty?
        get_ipam_subnet_by_cidr(cidr)
      else
        group_id = get_group_id(group_name)
        get_ipam_subnet_by_group(cidr, group_id)
      end
    end

    def get_ipam_subnet_by_group(cidr, group_id)
      params = { status: 'active', prefix: cidr, vrf_id: group_id }
      response = @api_resource.get("ipam/prefixes/", params)
      json_body = JSON.parse(response.body)
      return nil if json_body['count'].zero?
      subnet_from_result(json_body['results'][0])
    end

    def get_ipam_subnet_by_cidr(cidr)
      params = { status: 'active', prefix: cidr }
      response = @api_resource.get("ipam/prefixes/", params)
      json_body = JSON.parse(response.body)
      return nil if json_body['count'].zero?
      subnet_from_result(json_body['results'][0])
    end

    def ipam_groups
      response = @api_resource.get('ipam/vrfs/')
      json_body = JSON.parse(response.body)
      return [] if json_body['count'].zero?
      json_body['results'].map do |group|
        { name: group['name'], description: group['description'] }
      end
    end

    def get_ipam_group(group_name)
      raise ERRORS[:groups_not_supported] unless groups_supported?
      response = @api_resource.get("ipam/vrfs/?name=#{group_name}")
      json_body = JSON.parse(response.body)
      return nil if json_body['count'].zero?
      group_from_result(json_body['results'][0])
    end

    def get_group_id(group_name)
      return nil if group_name.nil? || group_name.empty?
      group = get_ipam_group(group_name)
      raise ERRORS[:no_group] if group.nil?
      group[:id]
    end

    def get_ipam_subnets(group_name)
      params = { status: 'active' }
      params[:vrf_id] = get_group_id(group_name) if group_name
      response = @api_resource.get("ipam/prefixes/", params)
      json_body = JSON.parse(response.body)
      return [] if json_body['count'].zero?
      subnets_from_result(json_body['results'])
    end

    def ip_exists?(ip, subnet_id, group_name)
      group_id = get_group_id(group_name)
      params = { address: ip }
      params[:prefix_id] = subnet_id unless subnet_id.nil?
      params[:vrf_id] = group_id unless group_id.nil?
      url = "ipam/ip-addresses/"
      response = @api_resource.get(url, params)
      json_body = JSON.parse(response.body)
      !json_body['count'].zero?
    end

    def add_ip_to_subnet(ip, params)
      desc = 'Address auto added by Foreman'
      address = "#{ip}/#{params[:cidr].split('/').last}"
      group_name = params[:group_name]
      data = { address: address, nat_outside: 0, description: desc }
      data[:vrf] = get_group_id(group_name) unless group_name.nil? || group_name.empty?
      response = @api_resource.post('ipam/ip-addresses/', data.to_json)
      return nil if response.code == '201'
      { error: "Unable to add #{address} in External IPAM server" }
    end

    def delete_ip_from_subnet(ip, params)
      group_name = params[:group_name]
      params = { address: ip }
      params[:vrf_id] = get_group_id(group_name) unless group_name.nil? || group_name.empty?
      response = @api_resource.get("ipam/ip-addresses/", params)
      json_body = JSON.parse(response.body)
      return { error: ERRORS[:no_ip] } if json_body['count'].zero?
      address_id = json_body['results'][0]['id']
      response = @api_resource.delete("ipam/ip-addresses/#{address_id}/")
      return nil if response.code == '204'
      { error: "Unable to delete #{ip} in External IPAM server" }
    end

    def get_next_ip(mac, cidr, group_name)
      subnet = get_ipam_subnet(cidr, group_name)
      raise ERRORS[:no_subnet] if subnet.nil?
      params = { limit: 1 }
      response = @api_resource.get("ipam/prefixes/#{subnet[:id]}/available-ips/", params)
      json_body = JSON.parse(response.body)
      return nil if json_body.empty?
      ip = json_body[0]['address'].split('/').first
      cache_next_ip(@ip_cache, ip, mac, cidr, subnet[:id], group_name)
    end

    def groups_supported?
      true
    end

    def authenticated?
      !@token.nil?
    end

    private

    def subnet_from_result(result)
      {
        subnet: result['prefix'].split('/').first,
        mask: result['prefix'].split('/').last,
        description: result['description'],
        id: result['id'],
      }
    end

    def subnets_from_result(result)
      result.map { |subnet| subnet_from_result(subnet) }
    end

    def group_from_result(result)
      {
        id: result['id'],
        name: result['name'],
        description: result['description'],
      }
    end
  end
end
