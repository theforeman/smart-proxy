require 'thread'

module Proxy::DependencyInjection
  class InstanceVariableWrapper
    def initialize(a_class)
      @a_class = a_class
    end

    def instance
      @a_class.new
    end
  end

  class SingletonWrapper
    def initialize(a_class)
      @mutex = Mutex.new
      @a_class = a_class
    end

    def instance
      @mutex.synchronize do
        @an_instance ||= @a_class.new
      end
    end
  end

  class Container
    def dependencies
      @dependencies ||= {}
    end

    def add_dependency(var_name, a_wrapper)
      dependencies[var_name] = a_wrapper
    end

    def get_dependency(var_name)
      raise "Dependency '#{var_name}' is undefined" unless dependencies.key?(var_name)
      dependencies[var_name]
    end

    def container_instance
      self
    end

    def self.instance
      @@instance ||= new
    end
  end

  module Wiring
    def singleton_dependency(var_name, a_class)
      container = container_instance
      container.add_dependency(var_name, Proxy::DependencyInjection::SingletonWrapper.new(a_class))
    end

    def dependency(var_name, a_class)
      container = container_instance
      container.add_dependency(var_name, Proxy::DependencyInjection::InstanceVariableWrapper.new(a_class))
    end
  end

  module Accessors
    def inject_attr reference, local_var
      container = container_instance
      define_method(local_var.to_sym) do
        if instance_variable_get("@#{local_var}").nil?
          instance_variable_set("@#{local_var}", container.get_dependency(reference).instance)
        else
          instance_variable_get("@#{local_var}")
        end
      end
      define_method("#{local_var}=") do |val|
        instance_variable_set("@#{local_var}", val)
      end
    end
  end
end
