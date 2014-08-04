require 'resolv'

module Sinatra
  module TrustedHosts
    def authorize_with_trusted_hosts
      helpers ::Proxy::Helpers

      before do
        # When :trusted_hosts is given, check the reverse DNS entry of the remote IP and ensure it's listed
        if Proxy::SETTINGS.trusted_hosts
          begin
            remote_fqdn = Resolv.new.getname(request.env["REMOTE_ADDR"])
          rescue Resolv::ResolvError => e
            log_halt 403, "Unable to resolve hostname for connecting client - #{request.env["REMOTE_ADDR"]}. If it's to be a trusted host, ensure it has a reverse DNS entry."  +
            "\n\n" + "#{e.message}"
          end
          if !Proxy::SETTINGS.trusted_hosts.include?(remote_fqdn.downcase)
            log_halt 403, "Untrusted client #{remote_fqdn.downcase} attempted to access #{request.path_info}. Check :trusted_hosts: in settings.yml"
          end
        end
      end
    end
  end
end
