require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/class_scanner_base'
require 'puppet_proxy/puppet_cache'
require 'tmpdir'

class PuppetCacheTest < Test::Unit::TestCase

  def setup
    @scanner = Proxy::Puppet::ClassScannerBase.new
    @scanner.stubs(:scan_manifest).returns([Proxy::Puppet::PuppetClass.new('testinclude')]).then.
        returns([Proxy::Puppet::PuppetClass.new('testinclude::sub::foo')])
  end

  def test_should_refresh_cache_when_dir_is_not_in_cache
    timestamp = Time.new
    Proxy::Puppet::PuppetCache.expects(:read_from_cache).returns({})
    Proxy::Puppet::PuppetCache.expects(:write_to_cache).with(
        {"./test/fixtures/modules_include" => {
            "testinclude" => {
                'timestamp' => timestamp.to_i,
                'manifest' => [
                  [::Proxy::Puppet::PuppetClass.new('testinclude')],
                  [::Proxy::Puppet::PuppetClass.new('testinclude::sub::foo')]]}
        }}, "example_env")
    Time.expects(:new).returns(timestamp)

    cache = Proxy::Puppet::PuppetCache.scan_directory_with_cache('./test/fixtures/modules_include', 'example_env', @scanner)

    assert_kind_of Array, cache
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert cache
    assert_equal "testinclude", klass.module

    klass = cache.find { |k| k.name == "testinclude" }
    assert klass
  end

  def test_should_refresh_cache_when_dir_is_changed
    mtime = File.mtime(Dir.glob('./test/fixtures/modules_include/*')[0]).to_i
    timestamp = Time.new

    Proxy::Puppet::PuppetCache.stubs(:read_from_cache).returns('./test/fixtures/modules_include' =>
                                                                   { 'testinclude' => { 'timestamp' => (mtime - 1000),
                                                                                        'manifest'  => [[Proxy::Puppet::PuppetClass.new('test')],
                                                                                                        [Proxy::Puppet::PuppetClass.new('test::sub::foo')]] }})
    Proxy::Puppet::PuppetCache.expects(:write_to_cache).with(
        {"./test/fixtures/modules_include" => {
            "testinclude" => {
                'timestamp' => timestamp.to_i,
                'manifest' => [
                  [::Proxy::Puppet::PuppetClass.new('testinclude')],
                  [::Proxy::Puppet::PuppetClass.new('testinclude::sub::foo')]]}
        }}, "example_env")
    Time.expects(:new).returns(timestamp)

    cache = Proxy::Puppet::PuppetCache.scan_directory_with_cache('./test/fixtures/modules_include', 'example_env', @scanner)

    assert_kind_of Array, cache
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert cache
    assert_equal "testinclude", klass.module

    klass = cache.find { |k| k.name == "testinclude" }
    assert klass
  end

  def test_cache_file_should_contain_version
    Dir.mktmpdir do |cache_dir|
      Proxy::Puppet::Plugin.load_test_settings(:cache_location => cache_dir)
      Proxy::Puppet::PuppetCache.write_to_cache({'./test/fixtures/modules_include' => {}}, 'production')
      assert File.read(File.expand_path("cache_production.json", cache_dir)).include?("\"version\":\"#{Proxy::Puppet::Plugin.version}\"")
    end
  end

  def test_should_return_empty_hash_when_cache_version_is_mismatched
    Dir.mktmpdir do |cache_dir|
      Proxy::Puppet::Plugin.load_test_settings(:cache_location => cache_dir)
      Proxy::Puppet::PuppetCache.write_to_cache({'./test/fixtures/modules_include' =>
                                                    { 'testinclude' => { 'timestamp' => Time.now.to_i,
                                                                         'manifest'  => [[Proxy::Puppet::PuppetClass.new('test')]] }}}, 'production')

      Proxy::Puppet::Plugin.expects(:version).returns("0.0.0.0.1")
      assert_equal({}, Proxy::Puppet::PuppetCache.read_from_cache('production'))
    end
  end

  def test_should_not_refresh_cache_when_cache_is_more_recent
    Proxy::Puppet::PuppetCache.stubs(:read_from_cache).returns('./test/fixtures/modules_include' =>
                                                                   { 'testinclude' => { 'timestamp' => Time.now.to_i,
                                                                                        'manifest'  => [[Proxy::Puppet::PuppetClass.new('test')],
                                                                                                        [Proxy::Puppet::PuppetClass.new('test::sub::foo')]] }})
    Proxy::Puppet::PuppetCache.expects(:write_to_cache).never
    cache = Proxy::Puppet::PuppetCache.scan_directory_with_cache('./test/fixtures/modules_include', 'example_env', @scanner)

    assert_kind_of Array, cache
    # reading from the cache returns two puppet classes
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert cache
    assert_equal "test", klass.module

    klass = cache.find { |k| k.name == "test" }
    assert klass
  end

  def test_read_write_cache_idempotency
    Dir.mktmpdir do |cache_dir|
      Proxy::Puppet::Plugin.load_test_settings(:cache_location => cache_dir)

      expected = {'./test/fixtures/modules_include' =>
                      {'testinclude' => { 'timestamp' => Time.now.to_i,
                                          'manifest'  => [[Proxy::Puppet::PuppetClass.new('test')],
                                                          [Proxy::Puppet::PuppetClass.new('test::sub::foo')]] }}}
      Proxy::Puppet::PuppetCache.write_to_cache(expected, 'production')
      assert_equal expected, Proxy::Puppet::PuppetCache.read_from_cache('production')
    end
  end
end
