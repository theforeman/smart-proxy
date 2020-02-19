module Proxy::PuppetCa::TokenWhitelisting
  class CSR
    attr_reader :csr

    def initialize(raw_csr)
      @csr = OpenSSL::X509::Request.new(raw_csr)
    end

    def challenge_password
      attribute = custom_attributes.detect do |attr|
        ['challengePassword', '1.2.840.113549.1.9.7'].include?(attr[:oid])
      end
      attribute ? attribute[:value] : nil
    end

    def custom_attributes
      @csr.attributes.map do |attr|
        {
          oid: attr.oid,
          value: attr.value.value.first.value,
        }
      end
    end
  end
end
