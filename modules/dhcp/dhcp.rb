$LOAD_PATH.unshift File.expand_path("../", __FILE__)

require 'dhcp/dhcp_plugin'

require "dhcp/record"
require "dhcp/record/lease"
require "dhcp/record/reservation"
require "dhcp/server"

module Proxy::DHCP
  Standard = {
              :hostname              => {:code => 12, :kind => "String"    }, # The host's name
              :PXEClient             => {:code => 60, :kind => "String"    }, # Needs to be empty for foreman to function
              :nextServer            => {:code => 66, :kind => "String"    }, # From where we download the pxeboot image via TFTP
              :filename              => {:code => 67, :kind => "String"    }  # The pxeboot image
             }
  SUNW     = {
              :root_server_ip        => {:code => 2,  :kind => "IPAddress" }, # 192.168.216.241
              :root_server_hostname  => {:code => 3,  :kind => "String"    }, # mediahost
              :root_path_name        => {:code => 4,  :kind => "String"    }, # /vol/solgi_5.10/sol10_hw0910/Solaris_10/Tools/Boot
              :install_server_ip     => {:code => 10, :kind => "IPAddress" }, # 192.168.216.241
              :install_server_name   => {:code => 11, :kind => "String"    }, # mediahost
              :install_path          => {:code => 12, :kind => "String"    }, # /vol/solgi_5.10/sol10_hw0910
              :sysid_server_path     => {:code => 13, :kind => "String"    }, # 192.168.216.241:/vol/jumpstart/sysidcfg/sysidcfg_primary
              :jumpstart_server_path => {:code => 14, :kind => "String"    }  # 192.168.216.241:/vol/jumpstart
             }
  class Error < RuntimeError; end
  class Collision < RuntimeError; end
  class InvalidRecord < RuntimeError; end
  class AlreadyExists < RuntimeError; end

  def kind
    self.class.to_s.sub("Proxy::DHCP::","").downcase
  end
end
