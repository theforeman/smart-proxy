require 'helpers'

class SmartProxy < Sinatra::Base
  before do
    if ['yes', 'on', '1'].include? request.env['HTTPS'].to_s
      if request.env['SSL_CLIENT_CERT'].to_s.empty?
        log_halt 403, "No client SSL certificate supplied"
      end
    else
      logger.debug('require_ssl_client_verification: skipping, non-HTTPS request')
    end
  end
end
