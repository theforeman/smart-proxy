# frozen_string_literal: true

# This module provides a set of helper methods that return mock data structures,
# mimicking the JSON responses from the ISC Kea API. This allows us to test the client
# and services without needing a live Kea server.
module KeaApiStubs
  # A successful response for a 'config-get' command.
  # @return [Hash] A hash representing the Kea DHCPv4 configuration.
  def successful_config_get
    {
      "Dhcp4" => {
        "subnet4" => [
          {
            "id" => 1,
            "subnet" => "192.168.1.0/24",
            "pools" => [{ "pool" => "192.168.1.10-192.168.1.20" }],
            "option-data" => [{ "name" => "routers", "data" => "192.168.1.1" }],
            "reservations" => [
              { "hw-address" => "aa:bb:cc:dd:ee:ff", "ip-address" => "192.168.1.5", "hostname" => "test-host" }
            ]
          }
        ]
      }
    }
  end

  # A config-get response with subnet-level options and reservation options.
  # @return [Hash] A hash representing a richer Kea DHCPv4 configuration.
  def config_get_with_options
    {
      "Dhcp4" => {
        "subnet4" => [
          {
            "id" => 1,
            "subnet" => "192.168.1.0/24",
            "pools" => [{ "pool" => "192.168.1.10-192.168.1.20" }],
            "next-server" => "192.168.1.254",
            "boot-file-name" => "pxelinux.0",
            "option-data" => [
              { "name" => "routers", "data" => "192.168.1.1" },
              { "name" => "domain-name-servers", "data" => "8.8.8.8,8.8.4.4" },
              { "name" => "domain-name", "data" => "example.com" },
              { "name" => "ntp-servers", "data" => "192.168.1.253" }
            ],
            "reservations" => [
              {
                "hw-address" => "aa:bb:cc:dd:ee:ff",
                "ip-address" => "192.168.1.5",
                "hostname" => "pxe-host",
                "next-server" => "192.168.1.254",
                "boot-file-name" => "pxelinux.0",
                "option-data" => [
                  { "name" => "routers", "data" => "192.168.1.1" },
                  { "name" => "domain-name-servers", "data" => "10.0.0.1,10.0.0.2" }
                ]
              }
            ]
          }
        ]
      }
    }
  end

  # A config-get whose boot fields hold Kea's "unset" placeholders: next-server
  # "0.0.0.0" and an empty boot-file-name, at both subnet and reservation level.
  # @return [Hash] A hash representing a Kea config with placeholder boot values.
  def config_get_with_placeholders
    {
      "Dhcp4" => {
        "subnet4" => [
          {
            "id" => 1,
            "subnet" => "192.168.1.0/24",
            "pools" => [{ "pool" => "192.168.1.10-192.168.1.20" }],
            "next-server" => "0.0.0.0",
            "boot-file-name" => "",
            "option-data" => [{ "name" => "routers", "data" => "192.168.1.1" }],
            "reservations" => [
              {
                "hw-address" => "aa:bb:cc:dd:ee:ff", "ip-address" => "192.168.1.5", "hostname" => "plain-host",
                "next-server" => "0.0.0.0", "boot-file-name" => "", "option-data" => []
              }
            ]
          }
        ]
      }
    }
  end

  # A successful 'reservation-get-all' response (hosts-database backend present).
  # Includes the static reservation from successful_config_get (to exercise dedup)
  # plus a database-only reservation.
  # @return [Hash] A hash containing a list of host reservations.
  def reservation_get_all_success
    {
      "hosts" => [
        { "hw-address" => "aa:bb:cc:dd:ee:ff", "ip-address" => "192.168.1.5", "hostname" => "test-host", "option-data" => [] },
        { "hw-address" => "11:22:33:44:55:66", "ip-address" => "192.168.1.30", "hostname" => "db-host", "option-data" => [] }
      ]
    }
  end

  # A config-get with multiple subnets for managed_subnets filtering tests.
  # @return [Hash] A hash with two subnets.
  def config_get_multi_subnet
    {
      "Dhcp4" => {
        "subnet4" => [
          {
            "id" => 1,
            "subnet" => "192.168.1.0/24",
            "pools" => [{ "pool" => "192.168.1.10-192.168.1.20" }],
            "option-data" => [{ "name" => "routers", "data" => "192.168.1.1" }],
            "reservations" => []
          },
          {
            "id" => 2,
            "subnet" => "10.0.0.0/24",
            "pools" => [{ "pool" => "10.0.0.10-10.0.0.100" }],
            "option-data" => [{ "name" => "routers", "data" => "10.0.0.1" }],
            "reservations" => []
          }
        ]
      }
    }
  end

  # A successful response for a 'lease4-get-all' command with one active lease.
  # @return [Hash] A hash containing a list of leases.
  def successful_lease_get
    {
      "leases" => [
        { "ip-address" => "192.168.1.11", "hw-address" => "ff:ee:dd:cc:bb:aa", "cltt" => 1678886400, "expire" => 1678890000 }
      ]
    }
  end

  # A successful response for a 'reservation-add' command.
  # @return [Hash] A hash indicating success.
  def successful_reservation_add
    { "result" => 0, "text" => "Reservation added successfully." }
  end

  # A successful response for a 'reservation-del' command.
  # @return [Hash] A hash indicating success.
  def successful_reservation_del
    { "result" => 0, "text" => "Reservation deleted successfully." }
  end

  # A successful response for a 'lease4-del' command.
  # @return [Hash] A hash indicating success.
  def successful_lease_del
    { "result" => 0, "text" => "Lease deleted successfully." }
  end

  # An error response from the API.
  # @return [Hash] A hash representing a generic API error.
  def error_response
    { "result" => 1, "text" => "Something went wrong." }
  end
end
