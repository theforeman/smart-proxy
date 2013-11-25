require 'test/test_helper'

class ClassScannerTest < Test::Unit::TestCase

  def setup
    Proxy::Puppet::Initializer.load
    @parser = Puppet::Parser::Parser.new Puppet::Node::Environment.new
  end

  def test_should_find_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    EOF
    klasses =  Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses =  Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses =  Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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

  def test_should_scan_a_dir
    klasses =  Proxy::Puppet::ClassScanner.scan_directory('/tmp/no_such_dir')
    assert_kind_of Array, klasses
    assert klasses.empty?
  end

  def test_should_extract_parameters__no_param_parenthesis
    manifest = <<-EOF
    class foreman::install {
    }
    EOF
    klasses = Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses = Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses = Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses = Proxy::Puppet::ClassScanner.scan_manifest(manifest, @parser)
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
    klasses =  Proxy::Puppet::ClassScanner.scan_directory('./test/fixtures/modules_include')
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size

    klass = klasses.find {|k| k.name == "sub::foo" }
    assert klass
    assert_equal "testinclude", klass.module

    klass = klasses.find {|k| k.name == "testinclude" }
    assert klass
  end

  #TODO add scans to a real puppet directory with modules

end
