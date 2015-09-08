require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/initializer'
require 'puppet_proxy/class_scanner'

module ClassScannerTestSuite
  def setup
    Proxy::Puppet::Plugin.load_test_settings(:puppet_conf => './test/fixtures/puppet.conf')
    Proxy::Puppet::Initializer.new.reset_puppet
  end

  def test_should_find_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    EOF
    klasses =  Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_not_file_a_class
    manifest = <<-EOF
      include 'x::y'
    EOF
    klasses =  Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert klasses.empty?
  end
  def test_should_find_multiple_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    class foreman::params {
      $var = 'xyz'
    }

    EOF
    klasses =  Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size
    klasses.sort! { |k1,k2| k1.name <=> k2.name }

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module

    klass = klasses.last

    assert_equal "params", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_scan_and_return_empty_array_when_directory_does_not_exist
    klasses =  Proxy::Puppet::ClassScanner.new.scan_directory('/tmp/no_such_dir', "example_env")
    assert_kind_of Array, klasses
    assert klasses.empty?
  end

  def test_should_extract_parameters__no_param_parenthesis
    manifest = <<-EOF
    class foreman::install {
    }
    EOF
    klasses = Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__empty_param_parenthesis
    manifest = <<-EOF
    class foreman::install () {
    }
    EOF
    klasses = Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__single_param_no_value
    manifest = <<-EOF
    class foreman::install ($mandatory) {
    }
    EOF
    klasses = Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({'mandatory' => nil}, klass.params)
  end

  def test_should_extract_parameters__type_coverage
    # Note that all keys are string in Puppet
    manifest = <<-EOF
    class foreman::install (
      $mandatory,
      $undef = undef,
      $emptyString = '',
      $emptyStringDq = "",
      $string = "foo",
      $integer = 42,
      $float = 3.14,
      $array = ['', "", "foo", 42, 3.14],
      $hash = { unquoted => '', "quoted" => "", 42 => "integer", 3.14 => "float", '' => 'empty' },
      $complex = { array => ['','foo',42,3.14], hash => {foo=>"bar"}, mixed => [{foo=>bar},{bar=>"baz"}] }
    ) {
    }
    EOF
    klasses = Proxy::Puppet::ClassScanner.new.scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({
                     'mandatory' => nil,
                     'undef' => '',
                     'emptyString' => '',
                     'emptyStringDq' => '',
                     'string' => 'foo',
                     'integer' => 42,
                     'float' => 3.14,
                     'array' => ['', '', 'foo', 42, 3.14],
                     # All keys must be strings
                     'hash' => { 'unquoted' => '', 'quoted' => '', '42' => 'integer', '3.14' => 'float', '' => 'empty' },
                     'complex' => { 'array' => ['','foo',42,3.14], 'hash' => {'foo'=>'bar'}, 'mixed' => [{'foo'=>'bar'},{'bar'=>'baz'}] }
                 }, klass.params)
  end

  def test_should_handle_import_in_a_manifest
    klasses =  Proxy::Puppet::ClassScanner.new.scan_directory('./test/fixtures/modules_include', "example_env")
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size

    klass = klasses.find {|k| k.name == "sub::foo" }
    assert klass
    assert_equal "testinclude", klass.module

    assert klasses.any? {|k| k.name == "testinclude" }
  end

  #TODO add scans to a real puppet directory with modules
end

if Puppet::PUPPETVERSION.to_i < 4
  class ClassScannerTest < Test::Unit::TestCase
    include ClassScannerTestSuite
  end
end
