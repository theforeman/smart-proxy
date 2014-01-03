require 'proxy/puppetdb'

class SmartProxy

  # generic query or essentially a pass through
  get '/puppetdb/*' do
     data = puppetdb.generic_query(params[:splat].join('/'), params[:query], params['order-by'])
  end

  private
  def puppetdb
    @puppetdb ||= Proxy::PuppetDB.new
  end
end