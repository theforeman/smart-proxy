require 'test_helper'
require 'launcher'

class LauncherTest < Test::Unit::TestCase
  def setup
    @launcher = Proxy::Launcher.new
  end

  def test_install_webrick_callback
    app1 = {app: 1}
    app2 = {app: 2}
    @launcher.install_webrick_callback!(app1, nil, app2)
    @launcher.expects(:launched).never
    app1[:StartCallback].call
    @launcher.expects(:launched).with([app1, app2])
    app2[:StartCallback].call
  end

  def test_launched_with_sdnotify
    @launcher.logger.expects(:info).with(includes('2 socket(s)'))
    ::SdNotify.expects(:ready)
    @launcher.launched([:app1, :app2])
  end
end
