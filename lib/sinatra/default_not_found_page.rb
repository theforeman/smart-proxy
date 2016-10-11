class Sinatra::Base
  error Sinatra::NotFound do
    content_type 'application/json'
    [404, 'Requested url was not found']
  end
end
