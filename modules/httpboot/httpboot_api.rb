require 'httpboot/request_limiter'

class Proxy::HttpbootApi < Sinatra::Base
  helpers ::Proxy::Helpers
  REQUEST_LIMITER = Proxy::Httpboot::RequestLimiter.new

  def self.request_limiter
    REQUEST_LIMITER
  end

  before do
    limit = Proxy::Httpboot::Plugin.settings.request_limit_5m
    allowed = limit.zero? || self.class.request_limiter.allow?(request.env['REMOTE_ADDR'], limit)
    halt 429, 'Too many requests' unless allowed
  end

  get "/*" do
    file = Pathname.new(params[:splat].first).cleanpath
    root = Pathname.new(Proxy::Httpboot::Plugin.settings.root_dir).expand_path.cleanpath
    joined_path = File.join(root, file)
    log_halt(404, "Not found") unless File.exist?(joined_path)
    real_file = Pathname.new(joined_path).realpath
    log_halt(403, "Invalid or empty path") unless real_file.fnmatch?("#{root}/**")
    log_halt(403, "Directory listing not allowed") if File.directory?(real_file)
    log_halt(503, "Not a regular file") unless File.file?(real_file)
    send_file real_file
  end
end
