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
    @storage.send(:lock) do
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

  def test_should_initialize_existing_empty_file
    file = Tempfile.new('autosign_empty_test')
    storage = Proxy::PuppetCa::TokenWhitelisting::TokenStorage.new file.path

    assert_equal [], storage.read
    storage.add 'foo.example.com'
    assert_equal ['foo.example.com'], storage.read
  ensure
    file.close
    file.unlink
  end

  def test_remove_returns_whether_entry_was_removed
    assert_true @storage.remove 'foo.example.com'
    assert_false @storage.remove 'does-not-exist.example.com'
  end

  def test_should_not_lose_concurrent_adds
    @storage.write []

    entries = Array.new(50) { |i| "host#{i}.example.com" }
    threads = entries.map do |entry|
      Thread.new { @storage.add entry }
    end
    threads.each(&:join)

    assert_equal entries.sort, @storage.read.sort
  end

  def test_concurrent_remove_only_succeeds_once
    @storage.write ['foo.example.com']

    results = Array.new(50) do
      Thread.new { @storage.remove 'foo.example.com' }
    end.map(&:value)

    assert_equal 1, results.count(true)
    assert_equal 49, results.count(false)
    assert_equal [], @storage.read
  end
end
