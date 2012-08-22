# Should only be accessible by Foreman
class SmartProxy
  # Having two handlers isn't DRY
  post %r{/squid/(add|rm)$} do
    require 'pp'
    pp params

    action = params[:captures].first
    host   = params[:host]

    begin
      log_halt 400, "Couldn't #{action} squid ACL: no host specified" unless host
      log_halt 500, "Failed to #{action} squid ACL" unless Proxy::Squid.send action.to_sym, host
    rescue => e
      log_halt 500, "Failed to #{action} squid configuration: #{e}"
    end
  end

end
