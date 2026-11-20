require 'test_helper'
require 'rack/test'
require 'smart_proxy_main'

# Rack 3 no longer makes rack.input rewindable by default; smart_proxy_main
# restores Rack 2 behaviour by using ::Rack::RewindableInput::Middleware.
class RewindableInputIntegrationTest < Test::Unit::TestCase
  include Proxy::IntegrationTestCase

  class RewindableInputApp < ::Sinatra::Base
    post '/echo' do
      request.body.rewind
      first = request.body.read
      request.body.rewind
      second = request.body.read
      [200, { 'Content-Type' => 'text/plain' }, ["#{first}|#{second}"]]
    end
  end

  def app
    RewindableInputApp.new
  end

  class TestPlugin < ::Proxy::Plugin
    class << self
      def http_rackup
        'run RewindableInputIntegrationTest::RewindableInputApp'
      end
    end
  end

  def test_middleware_is_used_when_available
    middleware = ::Sinatra::Base.middleware.map(&:first)
    if defined?(::Rack::RewindableInput::Middleware)
      assert_includes middleware, ::Rack::RewindableInput::Middleware,
                      'Rack 3+ requires Rack::RewindableInput::Middleware to keep rack.input rewindable'
    else
      # Rack 2 makes rack.input rewindable on its own; the middleware does not
      # exist there and must not be referenced unconditionally.
      assert_not_includes middleware.map(&:name), 'Rack::RewindableInput::Middleware'
    end
  end

  def test_request_body_can_be_read_twice
    Proxy::LogBuffer::Decorator.any_instance.stubs(:trace?).returns(true)
    launch protocol: 'http', plugins: [TestPlugin]
    res = Net::HTTP.new('localhost', @settings.http_port).post('/echo', 'hello world', 'CONTENT_TYPE' => 'text/plain')
    assert_kind_of Net::HTTPSuccess, res
    assert_equal 'hello world|hello world', res.body
  end

  # Rack::Test supplies a rewindable StringIO as rack.input, which would pass
  # trivially. Feed a stream without rewind/seek to prove the middleware
  # (on Rack 3) actually wraps it.
  class NonRewindableInput
    def initialize(data)
      @io = StringIO.new(data)
    end

    def read(*args)
      @io.read(*args)
    end

    def set_encoding(*args)
      @io.set_encoding(*args)
    end

    def size
      @io.size
    end
  end

  def test_non_rewindable_stream_becomes_rewindable
    unless defined?(::Rack::RewindableInput::Middleware)
      omit 'Rack 2 makes rack.input rewindable natively; nothing to wrap'
    end
    Proxy::LogBuffer::Decorator.any_instance.stubs(:trace?).returns(true)
    env = Rack::MockRequest.env_for('/echo',
                                    method: 'POST',
                                    input: NonRewindableInput.new('hello world'),
                                    'CONTENT_TYPE' => 'text/plain')
    status, _, body = RewindableInputApp.call(env)
    assert_equal 200, status
    assert_equal 'hello world|hello world', body.join
  end
end
