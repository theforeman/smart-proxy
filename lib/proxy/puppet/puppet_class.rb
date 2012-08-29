require 'puppet'

module Proxy::Puppet

  class PuppetClass

    class << self
      # scans a given directory and its sub directory for puppet classes
      # returns an array of PuppetClass objects.
      def scan_directory directory
        # Get a Puppet Parser to parse the manifest source
        parser = Puppet::Parser::Parser.new Puppet::Node::Environment.new
        Dir.glob("#{directory}/*/manifests/**/*.pp").map do |manifest|
          scan_manifest File.read(manifest), manifest, parser
        end.compact.flatten
      end

      def scan_manifest manifest, filename = '', parser = nil
        klasses = []
        # Get a Puppet Parser to parse the manifest source
        parser ||= Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
        already_seen = Set.new parser.known_resource_types.hostclasses.keys
        already_seen << '' # Prevent the toplevel "main" class from matching
        ast = parser.parse manifest
        # Get the parsed representation of the top most objects
        hostclasses = ast.respond_to?(:instantiate) ? ast.instantiate('') : ast.hostclasses.values
        hostclasses.each do |klass|
          # Only look at classes
          if klass.type == :hostclass and not already_seen.include? klass.namespace
            params = {}
            # Get parameters and eventual default values
            klass.arguments.each do |name, value|
              params[name] = ast_to_value(value) rescue nil
            end
            klasses << new(klass.namespace, params)
          end
        end
        klasses
      rescue => e
        puts "Error while parsing #{filename}: #{e}"
        klasses
      end

      private
      def ast_to_value value
        unless value.class.name.start_with? "Puppet::Parser::AST::"
          # Native Ruby types
          case value
            # Supported with exact JSON equivalent
            when NilClass, String, Numeric, Array, Hash, FalseClass, TrueClass
              value
            when Struct
              value.hash
            when Enumerable
              value.to_a
            # Stringified
            when Regexp # /(?:stringified)/
              "/#{value.to_s}/"
            when Symbol # stringified
              value.to_s
            else
              raise TypeError
          end
        else
          # Parser types
          case value
            # Supported with exact JSON equivalent
            when Puppet::Parser::AST::Boolean, Puppet::Parser::AST::String
              value.evaluate nil
            # Supported with stringification
            when Puppet::Parser::AST::Concat
              # Note1: only simple content are supported, plus variables whose raw name is taken
              # Note2: The variable substitution WON'T be done by Puppet from the ENC YAML output
              value.value.map do |v|
                case v
                  when Puppet::Parser::AST::String
                    v.evaluate nil
                  when Puppet::Parser::AST::Variable
                    "${#{v.value}}"
                  else
                    raise TypeError
                end
              end.join rescue nil
            when Puppet::Parser::AST::Type
              value.value
            when Puppet::Parser::AST::Name
              (Puppet::Parser::Scope.number?(value.value) or value.value)
            when Puppet::Parser::AST::Undef # equivalent of nil
              nil
            # Depends on content
            when Puppet::Parser::AST::ASTArray
              value.inject([]) { |arr, v| (arr << ast_to_value(v)) rescue arr }
            when Puppet::Parser::AST::ASTHash
              Hash[value.value.each.inject([]) { |arr, (k,v)| (arr << [ast_to_value(k), ast_to_value(v)]) rescue arr }]
            # Let's see if a raw evaluation works with no scope for any other type
            else
              if value.respond_to? :evaluate
                # Can probably work for: (depending on the actual content)
                # - Puppet::Parser::AST::ArithmeticOperator
                # - Puppet::Parser::AST::ComparisonOperator
                # - Puppet::Parser::AST::BooleanOperator
                # - Puppet::Parser::AST::Minus
                # - Puppet::Parser::AST::Not
                # May work for:
                # - Puppet::Parser::AST::InOperator
                # - Puppet::Parser::AST::MatchOperator
                # - Puppet::Parser::AST::Selector
                # Probably won't work for
                # - Puppet::Parser::AST::Variable
                # - Puppet::Parser::AST::HashOrArrayAccess
                # - Puppet::Parser::AST::ResourceReference
                # - Puppet::Parser::AST::Function
                value.evaluate nil
              else
                raise TypeError
              end
          end
        end
      end

    end

    def initialize name, params = {}
      @klass  = name || raise("Must provide puppet class name")
      @params = params
    end

    def to_s
      self.module.nil? ? name : "#{self.module}::#{name}"
    end

    # returns module name (excluding of the class name)
    def module
      klass[0..(klass.index("::")-1)] if has_module?(klass)
    end

    # returns class name (excluding of the module name)
    def name
      has_module?(klass) ? klass[(klass.index("::")+2)..-1] : klass
    end

    attr_reader :params

    private
    attr_reader :klass

    def has_module?(klass)
      !!klass.index("::")
    end

  end
end

