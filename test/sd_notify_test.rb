require 'test_helper'
require 'proxy/sd_notify'

class SdNotifyTest < Test::Unit::TestCase
  def test_active_with_notify_socket
    with_notify_socket('/mock/systemd/notify') do
      assert Proxy::SdNotify.new.active?
    end
  end

  def test_active_without_notify_socket
    with_notify_socket(nil) do
      refute Proxy::SdNotify.new.active?
    end
  end

  def test_notify
    assert_equal("TEST=42\n", with_test_socket { Proxy::SdNotify.new.notify('TEST=42') })
  end

  def test_notify_when_inactive
    assert_raises(RuntimeError) { with_notify_socket(nil) { Proxy::SdNotify.new.notify('TEST=42') } }
  end

  def test_ready
    assert_equal("READY=1\n", with_test_socket { Proxy::SdNotify.new.ready })
  end

  private

  def with_notify_socket(socket)
    old_socket = ENV.delete('NOTIFY_SOCKET')
    begin
      ENV['NOTIFY_SOCKET'] = socket unless socket.nil?
      yield
    ensure
      if old_socket.nil?
        ENV.delete('NOTIFY_SOCKET')
      else
        ENV['NOTIFY_SOCKET'] = old_socket
      end
    end
  end

  def with_test_socket(&block)
    socket_path = File.expand_path('../tmp/test_systemd.socket', __FILE__)
    File.delete(socket_path) if File.exist?(socket_path)

    socket = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM, 0)
    begin
      socket.bind(Socket.pack_sockaddr_un(socket_path))
      with_notify_socket(socket_path, &block)
      socket.recv_nonblock(256)
    ensure
      socket.close
    end
  end
end
