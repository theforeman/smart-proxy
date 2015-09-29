require 'puppet_proxy/puppet_class'
require 'puppet_proxy/class_scanner_base'

module Proxy::Puppet
  class ClassScanner < ClassScannerBase
    def scan_manifest manifest, filename = ''
      # FIX ME:
      # We must use this on puppet 2.6, as it appears to change its global state when used.
      # We should probably initialize puppet just once (during startup) on other platforms
      # as global state changes can lead to concurrency issues
      # If it's important to detect changes in environments without proxy restarts,
      # we should consider switching to environments api when they it's available.
      ::Proxy::Puppet::Initializer.new.reset_puppet
      parser = Puppet::Parser::Parser.new Puppet::Node::Environment.new
      klasses = []

      already_seen = Set.new parser.known_resource_types.hostclasses.keys
      already_seen << '' # Prevent the toplevel "main" class from matching
      ast = parser.parse manifest
                         # Get the parsed representation of the top most objects
      hostclasses = ast.respond_to?(:instantiate) ? ast.instantiate('') : ast.hostclasses.values
      hostclasses.each do |klass|
        # Only look at classes
        if klass.type == :hostclass && !already_seen.include?(klass.namespace)
          params = {}
          # Get parameters and eventual default values
          klass.arguments.each do |name, value|
            params[name] = ast_to_value(value) rescue nil
          end
          klasses << PuppetClass.new(klass.namespace, params)
        end
      end
      klasses
    rescue => e
      puts "Error while parsing #{filename}: #{e}"
      klasses
    end

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
          when Puppet::Parser::AST::Boolean, Puppet::Parser::AST::String
            value.evaluate nil
          # Supported with stringification
          when Puppet::Parser::AST::Concat
            # This is the case when two params are concatenated together ,e.g. "param_${key}_something"
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
          when Puppet::Parser::AST::Variable
            "${#{value}}"
          when Puppet::Parser::AST::Type
            value.value
          when Puppet::Parser::AST::Name
            (Puppet::Parser::Scope.number?(value.value) || value.value)
          when Puppet::Parser::AST::Undef # equivalent of nil, but optional
            ""
          # Depends on content
          when Puppet::Parser::AST::ASTArray
            value.inject([]) { |arr, v| (arr << ast_to_value(v)) rescue arr }
          when Puppet::Parser::AST::ASTHash
            Hash[value.value.each.inject([]) { |arr, (k,v)| (arr << [ast_to_value(k), ast_to_value(v)]) rescue arr }]
          when Puppet::Parser::AST::Function
            value.to_s
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
              value.evaluate nil
            else
              raise TypeError
            end
        end
      end
    end
  end
end