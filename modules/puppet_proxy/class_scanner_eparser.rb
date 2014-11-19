require 'puppet_proxy/puppet_class'
require 'puppet'

if Puppet::PUPPETVERSION.to_f >= 3.2
  require 'puppet/pops'

  module Proxy::Puppet
    class ClassScannerEParser
      class << self
        # scans a given directory and its sub directory for puppet classes
        # returns an array of PuppetClass objects.
        def scan_directory directory

          parser = Puppet::Pops::Parser::Parser.new
          Dir.glob("#{directory}/**/manifests/**/*.pp").map do |filename|
            scan_manifest File.read(filename), parser, filename
          end.compact.flatten
        end

        def scan_manifest manifest, parser, filename = ''
          klasses = []

          already_seen = Set.new
          already_seen << '' # Prevent the toplevel "main" class from matching
          ast = parser.parse_string manifest
          class_finder = ClassFinder.new

          class_finder.do_find ast.current
          klasses = class_finder.klasses

          klasses
        rescue => e
          puts "Error while parsing #{filename}: #{e}"
          klasses
        end
      end
    end

    class ClassFinder

      @@finder_visitor ||= Puppet::Pops::Visitor.new(nil,'find',0,0)

      attr_reader :klasses

      def initialize
        @klasses = []
      end

      def do_find ast
        @@finder_visitor.visit_this(self, ast)
      end

      def find_HostClassDefinition o
        params = {}
        o.parameters.each do |param|
          params[param.name] = ast_to_value_new(param.value) rescue nil
        end
        @klasses << PuppetClass.new(o.name, params)

        if o.body
          do_find(o.body)
        end
      end

      def find_BlockExpression o
        o.statements.collect {|x| do_find(x) }
      end

      def find_CallNamedFunctionExpression o
        if o.lambda
          do_find(o.lambda)
        end
      end

      def find_Program o
        if o.body
          do_find(o.body)
        end
      end

      def find_Object o
        #puts "Unhandled object:#{o}"
      end

      def ast_to_value_new value
        unless value.class.name.start_with? "Puppet::Pops::Model::"
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
              "/#{value}/"
            when Symbol # stringified
              value.to_s
            else
              raise TypeError
          end
        else
          # Parser types
          case value
            # Supported with exact JSON equivalent
            when Puppet::Pops::Model::BooleanExpression, Puppet::Pops::Model::LiteralString, Puppet::Pops::Model::LiteralNumber, Puppet::Pops::Model::QualifiedName
              (Puppet::Parser::Scope.number?(value.value) || value.value)
            when Puppet::Pops::Model::UnaryMinusExpression
              - ast_to_value_new(value.expr)
            when Puppet::Pops::Model::ArithmeticExpression
              ast_to_value_new(value.left_expr).send(value.operator, ast_to_value_new(value.right_expr))
            # Supported with stringification
            when Puppet::Pops::Model::ConcatenatedString
              # This is the case when two params are concatenated together ,e.g. "param_${key}_something"
              # Note1: only simple content are supported, plus variables whose raw name is taken
              # Note2: The variable substitution WON'T be done by Puppet from the ENC YAML output
              value.segments.map {|v| ast_to_value_new v}.join rescue nil
            when Puppet::Pops::Model::TextExpression
              ast_to_value_new value.expr
            when Puppet::Pops::Model::VariableExpression
              "${#{ast_to_value_new value.expr}}"
            when (Puppet::Pops::Model::TypeReference rescue nil)
              value.value
            when Puppet::Pops::Model::LiteralUndef
              ""
            # Depends on content
            when Puppet::Pops::Model::LiteralList
              value.values.inject([]) { |arr, v| (arr << ast_to_value_new(v)) rescue arr }
            when Puppet::Pops::Model::LiteralHash
              # Note that all keys are string in Puppet
              Hash[value.entries.inject([]) { |arr, entry| (arr << [ast_to_value_new(entry.key).to_s, ast_to_value_new(entry.value)]) rescue arr }]
            when Puppet::Pops::Model::NamedFunctionDefinition
              value.to_s
            # Let's see if a raw evaluation works with no scope for any other type
            else
              if value.respond_to? :value
                value.value
              elsif value.respond_to? :expr
                ast_to_value_new value.expr
              else
                raise TypeError
              end
          end
        end
      end
    end
  end
end
