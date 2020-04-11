module Proxy::Puppet
  class PuppetClass
    def initialize(name, params = {})
      @klass  = name || raise("Must provide puppet class name")
      @params = params
    end

    def to_s
      self.module.nil? ? name : "#{self.module}::#{name}"
    end

    # returns module name (excluding of the class name)
    def module
      klass[0..(klass.index("::") - 1)] if has_module?(klass)
    end

    # returns class name (excluding of the module name)
    def name
      has_module?(klass) ? klass[(klass.index("::") + 2)..-1] : klass
    end

    attr_reader :params
    attr_reader :klass

    def has_module?(klass)
      !!klass.index("::")
    end

    def to_json(*a)
      {
        'json_class' => self.class.name,
        'klass'      => klass,
        'params'     => params,
      }.to_json(*a)
    end

    def self.from_hash(o)
      new(o['klass'], o['params'])
    end

    def ==(other)
      klass == other.klass && params == other.params
    end
  end
end
