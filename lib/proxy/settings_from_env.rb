module Proxy::SettingsFromEnv
  def self.guess_setting_type(value)
    case value
    when Array
      :list
    when TrueClass, FalseClass
      :boolean
    when Float
      :float
    when Integer
      :integer
    when Symbol
      :symbol
    else
      :string
    end
  end

  def self.cast_value(type, value)
    case type
    when :integer
      value.to_i
    when :float
      value.to_f
    when :boolean
      !%w[0 false].include?(value.strip.downcase)
    when :list
      value.split(/[ ,]/)
    when :dict
      Hash[value.split(/[&,]/).map { |kv| kv.split('=') }]
    when :symbol
      value.to_sym
    when :string
      value
    else
      raise "Unsupported type #{type} for setting."
    end
  end
end
