# Additional DNS resource types not (yet) in rubysl-resolv

require 'resolv'

module DnsResources
  class SSHFP < Resolv::DNS::Resource
    TypeValue = 44 # :nodoc:
    ClassValue = 1

    def initialize(algorithm, type, fingerprint)
      @algorithm = algorithm
      @type = type
      @fingerprint = fingerprint
    end

    attr_reader :algorithm
    attr_reader :type
    attr_reader :fingerprint

    def encode_rdata(msg) # :nodoc:
      msg.put_pack('CC', @algorithm, @type)
      msg.put_bytes([@fingerprint].pack('H*'))
    end

    def self.decode_rdata(msg) # :nodoc:
      algorithm, type = msg.get_unpack('CC')
      fingerprint = msg.get_bytes.unpack('H*')[0]
      return self.new(algorithm, type, fingerprint)
    end

    def to_s # :nodoc:
      return "#{@algorithm} #{@type} #{@fingerprint}"
    end
  end
end
