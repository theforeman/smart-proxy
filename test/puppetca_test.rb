require 'test_helper'
require 'tempfile'
require 'fileutils'


class ProxyTest < Test::Unit::TestCase
  ## Helper for autosign files.
  def create_temp_autosign_file
    file = Tempfile.new('autosign_test')
    begin
      ## Setup
      FileUtils.cp './test/fixtures/autosign.conf', file.path
      Proxy::PuppetCA.stubs(:autosign_file).returns(file.path)
    rescue
      file.close
      file.unlink
      file = nil
    end
    file
  end

  def test_should_list_autosign_entries
    Proxy::PuppetCA.stubs(:autosign_file).returns('./test/fixtures/autosign.conf')
    assert_equal Proxy::PuppetCA.autosign_list, ['foo.example.com', '*.bar.example.com']
  end

  def test_should_add_autosign_entry
    file = create_temp_autosign_file
    content = []
    begin
      ## Execute
      Proxy::PuppetCA.autosign 'foobar.example.com'
      ## Read output
      content = file.read.split("\n")
    ensure
      file.close
      file.unlink
    end
    assert_equal content.include?('foobar.example.com'), true
  end

  def test_should_remove_autosign_entry
    file = create_temp_autosign_file
    content = ['foo.example.com']
    begin
      Proxy::PuppetCA.disable 'foo.example.com'
      content = file.read.split("\n")
    ensure
      file.close
      file.unlink
    end
    assert_equal content.include?('foo.example.com'), false
  end

  def test_should_have_a_logger
    assert_respond_to Proxy::PuppetCA, :logger
  end

  def test_which_should_return_a_binary_path
    ENV.stubs(:[]).with('PATH').returns(['/foo', '/bin', '/usr/bin'].join(File::PATH_SEPARATOR))
    { '/foo' => false, '/bin' => true, '/usr/bin' => false, '/usr/sbin' => false, '/usr/local/bin' => false, '/usr/local/sbin' => false }.each do |p,r|
      FileTest.stubs(:file?).with("#{p}/ls").returns(r)
      FileTest.stubs(:executable?).with("#{p}/ls").returns(r)
    end
    assert_equal '/bin/ls', Proxy::PuppetCA.which('ls')
  end

  def test_should_clean_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :clean
  end

  def test_should_disable_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :disable
  end

  def test_should_sign_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :sign
  end

end
