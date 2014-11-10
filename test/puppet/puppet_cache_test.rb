require 'test_helper'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/class_scanner_base'
require 'puppet_proxy/puppet_cache'

class PuppetCacheTest < Test::Unit::TestCase

  def setup
    @scanner = Proxy::Puppet::ClassScannerBase.new
    @scanner.stubs(:scan_manifest).returns([Proxy::Puppet::PuppetClass.new('testinclude')]).then.
                                   returns([Proxy::Puppet::PuppetClass.new('testinclude::sub::foo')])
    Proxy::Puppet::PuppetCache.stubs(:write_to_cache)
  end

  def test_should_refresh_cache_when_dir_is_not_in_cache
    Proxy::Puppet::PuppetCache.stubs(:read_from_cache).returns({})
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
    mtime = File.mtime(Dir.glob('./test/fixtures/modules_include/*')[0])

    Proxy::Puppet::PuppetCache.stubs(:read_from_cache).returns('./test/fixtures/modules_include' =>
                                                               { 'testinclude' => { :timestamp => mtime - 1000,
                                                                                    :manifest  => [[Proxy::Puppet::PuppetClass.new('test')],
                                                                                                   [Proxy::Puppet::PuppetClass.new('test::sub::foo')]] }})
    cache = Proxy::Puppet::PuppetCache.scan_directory_with_cache('./test/fixtures/modules_include', 'example_env', @scanner)

    assert_kind_of Array, cache
    assert_equal 2, cache.size

    klass = cache.find { |k| k.name == "sub::foo" }
    assert cache
    assert_equal "testinclude", klass.module

    klass = cache.find { |k| k.name == "testinclude" }
    assert klass
  end

  def  test_should_not_refresh_cache_when_cache_is_more_recent
    Proxy::Puppet::PuppetCache.stubs(:read_from_cache).returns('./test/fixtures/modules_include' =>
                                                               { 'testinclude' => { :timestamp => Time.now,
                                                                                    :manifest  => [[Proxy::Puppet::PuppetClass.new('test')],
                                                                                                   [Proxy::Puppet::PuppetClass.new('test::sub::foo')]] }})
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
end