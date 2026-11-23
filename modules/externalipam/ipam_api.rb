require 'proxy/validations'
require 'externalipam/ipam_helper'
require 'externalipam/ipam_validator'
require 'externalipam/dependency_injection'

module Proxy::Ipam
  # Generic API for External IPAM interactions
  class Api < ::Sinatra::Base
    extend Proxy::Ipam::DependencyInjection
    include ::Proxy::Log
    include ::Proxy::Validations
    helpers ::Proxy::Helpers
    include Proxy::Ipam::IpamHelper
    include Proxy::Ipam::IpamValidator

    inject_attr :externalipam_client, :client

    # Gets the next available IP address based on a given External IPAM subnet
    #
    # Inputs:   1. address:          Network address of the subnet(e.g. 100.55.55.0)
    #           2. prefix:           Network prefix(e.g. 24)
    #           3. group(optional):  The External IPAM group
    #
    # Returns:
    #   Response if success:
    #   ======================
    #     Http Code:     200
    #     JSON Response:
    #       "100.55.55.3"
    #
    #   Response if missing parameter(e.g. 'mac')
    #   ======================
    #     Http Code:     400
    #     JSON Response:
    #       {"error": "A 'mac' address must be provided(e.g. 00:0a:95:9d:68:10)"}
    #
    #   Response if no free ip's available
    #   ======================
    #     Http Code:     404
    #     JSON Response:
    #       {"error": "There are no free IP's in subnet 100.55.55.0/24"}
    get '/subnet/:address/:prefix/next_ip' do
      content_type :json

      validate_required_params!([:address, :prefix], params)
      mac_param = params[:mac]
      mac = validate_mac(params[:mac]) unless mac_param.nil? || mac_param.empty?
      cidr = validate_cidr(params[:address], params[:prefix])
      group_name = get_request_group(params)
      next_ip = provider.get_next_ip(mac, cidr, group_name)
      halt 404, { error: ERRORS[:no_free_ips] }.to_json if next_ip.nil?
      { data: next_ip }.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Gets the subnet from External IPAM
    #
    # Inputs:   1. address:          Network address of the subnet
    #           2. prefix:           Network prefix(e.g. 24)
    #           3. group(optional):  The name of the External IPAM group
    #
    # Returns:
    #   Response if subnet exists:
    #   ===========================
    #     Http Code:     200
    #     JSON Response:
    #       {"data": {
    #         "id": "33",
    #         "subnet": "10.20.30.0",
    #         "description": "Subnet description",
    #         "mask": "29"}
    #       }
    #
    #   Response if subnet does not exist:
    #   ===========================
    #     Http Code:     404
    #     JSON Response:
    #       {"error": "No subnets found"}
    get '/subnet/:address/:prefix' do
      content_type :json

      validate_required_params!([:address, :prefix], params)
      cidr = validate_cidr(params[:address], params[:prefix])
      group_name = get_request_group(params)
      subnet = provider.get_ipam_subnet(cidr, group_name)
      halt 404, { error: ERRORS[:no_subnet] }.to_json if subnet.nil?
      subnet.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Get a list of groups from External IPAM
    #
    # Returns:
    #   Response if success:
    #   ===========================
    #     Http Code:     200
    #     JSON Response:
    #       {"data": [
    #         {"id": "1", "name": "Group 1", "description": "This is group 1"},
    #         {"id": "2", "name": "Group 2", "description": "This is group 2"}
    #       ]}
    #
    #   Response if no groups exist:
    #   ===========================
    #     Http Code:     404
    #     JSON Response:
    #       {"error": "Groups are not supported"}
    #
    #   Response if groups are not supported:
    #   ===========================
    #     Http Code:     422
    #     JSON Response:
    #       {"error": "Groups are not supported"}
    get '/groups' do
      content_type :json

      halt 422, { error: ERRORS[:groups_not_supported] }.to_json unless provider.groups_supported?
      groups = provider.ipam_groups
      groups.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Get a group from External IPAM
    #
    # Inputs:   1. group:       The name of the External IPAM group
    #
    # Returns:
    #   Response if success:
    #   ===========================
    #     Http Code:     200
    #     JSON Response:
    #       {"data": {"id": "1", "name": "Group 1", "description": "This is group 1"}}
    #
    #   Response if group not found:
    #   ===========================
    #     Http Code:     404
    #     JSON Response:
    #       {"error": "Group not Found"}
    #
    #   Response if groups are not supported:
    #   ===========================
    #     Http Code:     500
    #     JSON Response:
    #       {"error": "Groups are not supported"}
    get '/groups/:group' do
      content_type :json

      validate_required_params!([:group], params)
      group_name = get_request_group(params)
      group = provider.get_ipam_group(group_name)
      halt 404, { error: ERRORS[:no_group] }.to_json if group.nil?
      group.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Get a list of subnets for a given External IPAM group
    #
    # Input:   1. group:         The name of the External IPAM group
    #
    # Returns:
    #   Response if success:
    #   ===========================
    #     Http Code:     200
    #     JSON Response:
    #       {"data":[
    #         {"subnet":"10.20.30.0","mask":"29","description":"This is a subnet"},
    #         {"subnet":"40.50.60.0","mask":"29","description":"This is another subnet"}
    #       ]}
    #
    #   Response if no subnets exist in group:
    #   ===========================
    #     Http Code:     404
    #     JSON Response:
    #       {"error": "No subnets found in External IPAM group"}
    #
    #   Response if groups are not supported:
    #   ===========================
    #     Http Code:     500
    #     JSON Response:
    #       {"error": "Groups are not supported"}
    get '/groups/:group/subnets' do
      content_type :json

      validate_required_params!([:group], params)
      group_name = get_request_group(params)
      subnets = provider.get_ipam_subnets(group_name)
      halt 404, { error: ERRORS[:no_subnets_in_group] }.to_json if subnets == []
      subnets.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Checks whether an IP address has already been taken in External IPAM
    #
    # Inputs: 1. address:         The network address of the IPv4 or IPv6 subnet.
    #         2. prefix:          The subnet prefix(e.g. 24)
    #         3. ip:              IP address to be queried
    #         4. group(optional): The name of the External IPAM Group, containing the subnet to check
    #
    # Returns:
    #   Response if exists:
    #   ===========================
    #     Http Code:  200
    #     Response:   true
    #
    #   Response if not exists:
    #   ===========================
    #     Http Code:      200
    #     JSON Response:  false
    get '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :prefix, :ip], params)
      ip = validate_ip(params[:ip])
      cidr = validate_cidr(params[:address], params[:prefix])
      group_name = get_request_group(params)
      subnet = provider.get_ipam_subnet(cidr, group_name)
      halt 404, { error: ERRORS[:no_subnet] }.to_json if subnet.nil?
      validate_ip_in_cidr(ip, cidr)
      ip_exists = provider.ip_exists?(ip, subnet[:id], group_name)
      halt 200, { result: ip_exists }.to_json
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Adds an IP address to the specified subnet for the specified IPAM provider
    #
    # Params: 1. address:         The network address of the IPv4 or IPv6 subnet
    #         2. prefix:          The subnet prefix(e.g. 24)
    #         3. ip:              IP address to be added
    #         4. group(optional): The name of the External IPAM Group, containing the subnet to add ip to
    #
    # Returns:
    #   Response if added successfully:
    #   ===========================
    #     Http Code:  201
    #     Response:   Empty
    #
    #   Response if not added successfully:
    #   ===========================
    #     Http Code:  500
    #     JSON Response:
    #       {"error": "Unable to add IP to External IPAM"}
    post '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :ip, :prefix], params)
      ip = validate_ip(params[:ip])
      cidr = validate_cidr(params[:address], params[:prefix])
      group_name = get_request_group(params)
      subnet = provider.get_ipam_subnet(cidr, group_name)
      halt 404, { error: ERRORS[:no_subnet] }.to_json if subnet.nil?
      add_ip_params = { cidr: cidr, subnet_id: subnet[:id], group_name: group_name }
      validate_ip_in_cidr(ip, cidr)
      ip_added = provider.add_ip_to_subnet(ip, add_ip_params) # Returns nil on success
      halt 500, ip_added.to_json unless ip_added.nil?
      status 201
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end

    # Deletes IP address from a given subnet
    #
    # Params: 1. address:         The network address of the IPv4 or IPv6 subnet
    #         2. prefix:          The subnet prefix(e.g. 24)
    #         3. ip:              IP address to be deleted
    #         4. group(optional): The name of the External IPAM Group, containing the subnet to delete ip from
    #
    # Returns:
    #   Response if deleted successfully:
    #   ===========================
    #     Http Code:  200
    #     Response:   Empty
    #
    #   Response if not added successfully:
    #   ===========================
    #     Http Code:  500
    #     JSON Response:
    #       {"error": "Unable to delete IP from External IPAM"}
    delete '/subnet/:address/:prefix/:ip' do
      content_type :json

      validate_required_params!([:address, :ip, :prefix], params)
      ip = validate_ip(params[:ip])
      cidr = validate_cidr(params[:address], params[:prefix])
      group_name = get_request_group(params)
      subnet = provider.get_ipam_subnet(cidr, group_name)
      halt 404, { error: ERRORS[:no_subnet] }.to_json if subnet.nil?
      del_ip_params = { cidr: cidr, subnet_id: subnet[:id], group_name: group_name }
      validate_ip_in_cidr(ip, cidr)
      ip_deleted = provider.delete_ip_from_subnet(ip, del_ip_params) # Returns nil on success
      halt 500, ip_deleted.to_json unless ip_deleted.nil?
      halt 204
    rescue Proxy::Validations::Error => e
      logger.exception(ERRORS[:proxy_validation_error], e)
      halt 400, { error: e.to_s }.to_json
    rescue RuntimeError => e
      logger.exception(ERRORS[:runtime_error], e)
      halt 500, { error: e.to_s }.to_json
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      logger.exception(ERRORS[:no_connection], e)
      halt 500, { error: ERRORS[:no_connection] }.to_json
    end
  end
end
