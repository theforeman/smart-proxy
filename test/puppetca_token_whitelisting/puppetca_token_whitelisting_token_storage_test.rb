require 'test_helper'

require 'timeout'
require 'puppetca/puppetca'
require 'puppetca_token_whitelisting/puppetca_token_whitelisting_token_storage'

class PuppetCaTokenWhitelistingTokenStorageTest < Test::Unit::TestCase
  def setup
    @file = Tempfile.new('autosign_test')
    begin
      ## Setup
      FileUtils.cp './test/fixtures/puppetca/storage.yml', @file.path
    rescue
      @file.close
      @file.unlink
      @file = nil
    end
    @storage = Proxy::PuppetCa::TokenWhitelisting::TokenStorage.new @file.path
  end

  def teardown
    @file.close
    @file.unlink
  end

  def test_should_be_able_to_read_file
    result = @storage.read
    assert_equal ['foo.example.com', 'test.bar.example.com'], result
  end

  def test_should_be_able_to_write_file
    data = ['42.foo.example.com', 'baz.example.com']
    @storage.write data
    assert_equal data, @storage.read
  end

  def test_should_be_able_to_add_elements
    @storage.add 'baz.example.com'
    assert_equal ['foo.example.com', 'test.bar.example.com', 'baz.example.com'], @storage.read
  end

  def test_should_be_able_to_remove_elements
    @storage.remove 'foo.example.com'
    assert_equal ['test.bar.example.com'], @storage.read
  end

  def test_should_queue_writes_when_locked
    @storage.lock do
      assert_raise Timeout::Error do
        Timeout.timeout(3) do
          @storage.write ['test']
        end
      end
    end
  end

  def test_remove_if_works
    @storage.remove_if do |token|
      token.start_with? 'foo'
    end
    assert_equal ['test.bar.example.com'], @storage.read
  end
end
