module Sinatra
  module MonkeyRequest
    # We need request.accept? method also in pre-1.3.0 versions. This is simplified
    # version of the method that only accept one parameter (mime type string).
    def accept?(type)
      accept.include? type
    end
  end
  Request.send :include, MonkeyRequest unless Request.method_defined?(:accept?)
end
