require "test/unit"
require 'fileutils'

$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__), '..', 'modules')

logdir = File.join(File.dirname(__FILE__), '..', 'logs')
FileUtils.mkdir_p(logdir) unless File.exist?(logdir)

ENV['RACK_ENV'] = 'test'

# Make sure that tests put their temp files in a controlled location
# Clear temp file before each test run
ENV['TMPDIR'] = 'test/tmp'
FileUtils.rm_f Dir.glob 'test/tmp/*.tmp'

require "mocha/test_unit"
require "rack/test"
require 'timeout'
require 'webmock/test_unit'

require 'smart_proxy_for_testing'
require 'provider_interface_validation/dhcp_provider'

include DhcpProviderInterfaceValidation

def hash_symbols_to_strings(hash)
  Hash[hash.collect{|k,v| [k.to_s,v]}]
end

# Starts up a real smart proxy instance under WEBrick
# Use sparingly.  API tests should use rack-test etc.
module Proxy::IntegrationTestCase
  include Proxy::Log

  def setup
    WebMock.allow_net_connect!
  end

  def launch(protocol: 'https', plugins: [], settings: {})
    port = 1024 + rand(63_000)
    @settings = Proxy::Settings::Global.new(settings.merge("#{protocol}_port" => port))
    @t = Thread.new do
      launcher = Proxy::Launcher.new(@settings)
      app = launcher.public_send("#{protocol}_app", port, plugins)
      launcher.webrick_server(app.merge(AccessLog: [Logger.new('/dev/null')]), ['localhost'], port).start
    end
    Timeout::timeout(2) do
      sleep(0.1) until can_connect?('localhost', @settings.send("#{protocol}_port"))
    end
  end

  def can_connect?(host, port)
    TCPSocket.new(host, port).close
    true
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    false
  end

  def teardown
    WebMock.disable_net_connect!
    if @t
      Thread.kill(@t)
      @t.join(30)
    end
  end
end
