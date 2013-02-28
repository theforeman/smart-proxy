# Should only be accessible by Foreman
class SmartProxy
  post '/squid/add' do
    host   = params[:host]

    begin
      log_halt 400, "Couldn't add squid ACL: no host specified" unless host
      log_halt 500, "Failed to add squid ACL" unless Proxy::Squid.add host
    rescue => e
      log_halt 500, "Failed to add squid configuration: #{e}"
    end
  end

  delete '/squid/rm' do
    host   = params[:host]

    begin
      log_halt 400, "Couldn't remove squid ACL: no host specified" unless host
      log_halt 500, "Failed to remove squid ACL" unless Proxy::Squid.rm host
    rescue => e
      log_halt 500, "Failed to remove squid configuration: #{e}"
    end
  end

end
