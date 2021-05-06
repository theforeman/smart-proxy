require 'proxy/log_buffer/decorator'
require 'proxy/log_buffer/buffer'

class Proxy::LogsApi < Sinatra::Base
  helpers ::Proxy::Helpers

  get "/" do
    content_type :json
    buffer = ::Proxy::LogBuffer::Buffer.instance
    from_timestamp = params[:from_timestamp].to_f rescue 0
    records = buffer.to_a(from_timestamp).collect(&:to_h)
    { :info => buffer.info, :logs => records }.to_json
  rescue => e
    log_halt 400, e
  end
end
