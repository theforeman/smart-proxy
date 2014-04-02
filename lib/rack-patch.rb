class Rack::Server
  def initialize(options = nil)
    @options = options
    @app = options[:app] if options && options[:app]
  end
end
