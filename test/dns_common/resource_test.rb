require 'test_helper'
require 'dns_common/dns_resources'

class DnsResourceTest < Test::Unit::TestCase
  def setup
    @sshfp = DnsResources::SSHFP.new(1, 2, "D87F5D91F1153AE4C9490144F3E1A9CA7CAEE634")
  end

  def test_sshfp_converts_to_string
    assert_equal "1 2 D87F5D91F1153AE4C9490144F3E1A9CA7CAEE634", @sshfp.to_s
  end

  def test_sshfp_encode
    msg = Resolv::DNS::Message.new
    msg.expects(:put_pack).with('CC', 1, 2)
    msg.expects(:put_bytes).with(['D87F5D91F1153AE4C9490144F3E1A9CA7CAEE634'].pack('H*'))
    assert_nil @sshfp.encode_rdata(msg)
  end

  def test_sshfp_decode
    msg = Resolv::DNS::Message.new
    msg.expects(:get_unpack).with('CC').returns([1, 2])
    msg.expects(:get_bytes).with().returns(['D87F5D91F1153AE4C9490144F3E1A9CA7CAEE634'].pack('H*'))
    result = DnsResources::SSHFP.decode_rdata(msg)
    assert_equal 1, result.algorithm
    assert_equal 2, result.type
    assert_equal "D87F5D91F1153AE4C9490144F3E1A9CA7CAEE634", result.fingerprint.upcase
  end
end
