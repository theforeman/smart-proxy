require 'test_helper'
require 'launcher'
require 'puma'
require 'rack/handler/puma'
require 'puma-patch'

class LauncherTest < Test::Unit::TestCase
  def setup
    @launcher = Proxy::Launcher.new
    @launcher.stubs(:pid_path).returns("launcher_test.pid")
  end

  def test_pid_status_exited
    assert_equal :exited, @launcher.pid_status
  end

  def test_write_pid_success
    @launcher.write_pid
    assert File.exist?(@launcher.pid_path)
  ensure
    FileUtils.rm_f @launcher.pid_path
  end

  def test_pid_status_running
    @launcher.write_pid
    assert_equal :running, @launcher.pid_status
  ensure
    FileUtils.rm_f @launcher.pid_path
  end

  def test_check_pid_deletes_dead
    Process.stubs(:kill).returns { raise Errno::ESRCH }
    @launcher.check_pid
    assert_equal false, File.exist?(@launcher.pid_path)
  end

  def test_check_pid_exits_program
    @launcher.write_pid
    assert_raises SystemExit do
      @launcher.check_pid
    end
  ensure
    FileUtils.rm_f @launcher.pid_path
  end

  def test_add_webrick_server_callback
    an_app = {}
    sdn = Proxy::SdNotifyAll.new(2)
    sdn.stubs(:status)
    sdn.expects(:ready)
    @launcher.add_webrick_server_callback(an_app, sdn)
    an_app[:StartCallback].call
    an_app[:StartCallback].call
  end

  def test_add_puma_server_callback
    sdn = Proxy::SdNotifyAll.new(2)
    sdn.stubs(:status)
    sdn.expects(:ready)
    events = @launcher.add_puma_server_callback(sdn)
    events.fire(:state, :running)
    events.fire(:state, :running)
  end
end
