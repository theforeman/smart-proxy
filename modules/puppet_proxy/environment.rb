require 'puppet_proxy/dependency_injection/container'

class Proxy::Puppet::Environment
  extend Proxy::Puppet::DependencyInjection::Injectors
  inject_attr :puppet_cache_impl, :puppet_class_scanner
  inject_attr :environments_retriever_impl, :environments_retriever

  class << self
    def all
      new(:name => "", :paths => "").all
    end

    def find name
      all.find { |e| e.name == name }
    end
  end

  attr_reader :name, :paths

  def initialize args
    @name = args[:name].to_s || raise("Must provide a name")
    @paths= args[:paths]     || raise("Must provide a path")
  end

  def to_s
    name
  end

  def classes
    paths.map {|path| puppet_class_scanner.scan_directory(path, name) }.flatten
  end

  def all
    environments_retriever.all
  end
end
