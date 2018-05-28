require 'test_helper'
require 'tempfile'
require 'fileutils'

require 'puppetca/puppetca'
require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting'
require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting_autosigner'

class PuppetCaHostnameWhitelistingAutosignerTest < Test::Unit::TestCase
  def setup
    @file = Tempfile.new('autosign_test')
    begin
      ## Setup
      FileUtils.cp './test/fixtures/autosign.conf', @file.path
    rescue
      @file.close
      @file.unlink
      @file = nil
    end
    @autosigner = Proxy::PuppetCa::HostnameWhitelisting::Autosigner.new
    @autosigner.stubs(:autosign_file).returns(@file.path)
  end

  def test_should_list_autosign_entries
    assert_equal @autosigner.autosign_list, ['foo.example.com', '*.bar.example.com']
  end

  def test_should_add_autosign_entry
    content = []
    begin
      ## Execute
      @autosigner.autosign 'foobar.example.com'
      ## Read output
      content = @file.read.split("\n")
    ensure
      @file.close
      @file.unlink
    end
    assert_true content.include?('foobar.example.com')
  end

  def test_should_not_duplicate_autosign_entry
    begin
      before_content = @file.read
      @file.seek(0)
      ## Execute
      @autosigner.autosign 'foo.example.com'
      ## Read output
      after_content = @file.read
    ensure
      @file.close
      @file.unlink
    end
    assert_equal before_content, after_content
  end

  def test_should_remove_autosign_entry
    begin
      @autosigner.disable 'foo.example.com'
      content = @file.read
    ensure
      @file.close
      @file.unlink
    end
    assert_false content.split("\n").include?('foo.example.com')
    assert_true content.end_with?("\n")
  end
end
