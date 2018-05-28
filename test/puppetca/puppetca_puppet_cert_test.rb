require 'test_helper'
require 'tempfile'
require 'fileutils'

require 'puppetca/puppetca'
require 'puppetca/puppetca_puppet_cert'

class PuppetCaCertmanagerTest < Test::Unit::TestCase
  def setup
    @puppet_cert = Proxy::PuppetCa::PuppetCert.new
  end

  def test_which_should_return_a_binary_path
    ENV.stubs(:[]).with('PATH').returns(['/foo', '/bin', '/usr/bin'].join(File::PATH_SEPARATOR))
    { '/foo' => false, '/bin' => true, '/usr/bin' => false, '/usr/sbin' => false, '/usr/local/bin' => false, '/usr/local/sbin' => false }.each do |p,r|
      FileTest.stubs(:file?).with("#{p}/ls").returns(r)
      FileTest.stubs(:executable?).with("#{p}/ls").returns(r)
    end
    assert_equal '/bin/ls', @puppet_cert.which('ls')
  end

  INVENTORY_CONTENTS =<<EOF
0x0002 2015-09-01T15:15:57UTC 2020-08-31T15:15:57UTC /CN=revoked.my.domain
0x0003 2015-09-02T08:34:59UTC 2020-09-01T08:34:59UTC /CN=active.my.domain
0x0004 2017-01-11T15:04:35UTC 2022-01-11T15:04:35UTC /CN=revoked.my.domain
0x0005 2017-01-14T12:01:22UTC 2022-01-14T12:01:22UTC /CN=second-active.my.domain/OU=mydepartment
EOF
  def test_parse_inventory
    assert_equal({"revoked.my.domain" => {:serial => 4, :not_before => "2017-01-11T15:04:35UTC", :not_after => "2022-01-11T15:04:35UTC"},
                  "active.my.domain" => {:serial => 3, :not_before => "2015-09-02T08:34:59UTC", :not_after => "2020-09-01T08:34:59UTC"},
                  "second-active.my.domain" => {:serial => 5, :not_before => "2017-01-14T12:01:22UTC", :not_after => "2022-01-14T12:01:22UTC"}},
                 @puppet_cert.parse_inventory(INVENTORY_CONTENTS))
  end

  CRL_CONTENTS =<<EOF
-----BEGIN X509 CRL-----
MIIC9DCB3QIBATANBgkqhkiG9w0BAQUFADA0MTIwMAYDVQQDDClQdXBwZXQgQ0E6
IGx1Y2lkLW5vbnNlbnNlLmFwcGxpZWRsb2dpYy5jYRcNMTcwMTEyMTUzNjM1WhcN
MjIwMTExMTUzNjM2WjBEMCACAQIXDTE3MDExMjEzMDEwOVowDDAKBgNVHRUEAwoB
ATAgAgEEFw0xNzAxMTIxNTM2MzZaMAwwCgYDVR0VBAMKAQGgLzAtMB8GA1UdIwQY
MBaAFPXwC6fTTZGAEGWebeMJobxzTq0IMAoGA1UdFAQDAgECMA0GCSqGSIb3DQEB
BQUAA4ICAQBevzkpnkJOelipZsd8GbV5r7b/5Mc/X9fIoNb7wfDGzRWMNDvp/pqd
3TeXvHKsgFqjgchQlI+dd+K1eouJm3pYSsT5MYVrJYUJ6kzPgC89tgtEDApnYOjx
rZIWyF6PeWjL8E7ZKNVFX6RS2HbhWLZStDnkJvckXAhN4GXdLdm5FulkXQ7asQTy
8u1bXWDvRESNuveHuuVyQpfzbnznxUSgf+gJzQ35wbNGZCJDoNlEth6UnIz26LIY
/3dRt/HcybDLoSIV+PF7m2VZZxwcpRCIgjvhCz0fWdfakPYoCn5l3ZGZnv6vL/ss
Mt7bh+b9C0u4g9sQxAYsW21EEFcxVjREXQNn9t/9iqwNn+W90Fee3TJGmWQINO29
zzPgmYyWZQFHCVPuQE/R6cVrRIFte1PjEycsxcTjVv4f71vIWd/54VW7/7TjXYq5
7CnBxWUlWs8N8GwJLzem5DgJvF85YUbVACfNs8JhZc7osLPxFhnZcKz2dLyJgXOj
tzZtHJZG7qxR1n9GmERVpk6OSeK0KKYmb+N9u4mGXYTDG6kl+nj1dU/Uh/yoAwG8
UCEaly81c8sSHjLI3GetK4WxND0cElcSaFY3q22bDay7drhhCMftcbhxoh9ROI5h
Ldr9eKhzX/iwBRnlcwxVCLSUEP+46oGi8hawrhEUnPxPtftMjPVFTQ==
-----END X509 CRL-----
EOF
  def test_revoked_serials
   assert_equal Set.new([2, 4]), @puppet_cert.revoked_serials(CRL_CONTENTS)
  end

  def test_compute_ca_inventory
    assert_equal({"revoked.my.domain"=>{:serial=>4, :not_before=>"2017-01-11T15:04:35UTC", :not_after=>"2022-01-11T15:04:35UTC", :state=>"revoked"},
                  "active.my.domain"=>{:serial=>3, :not_before=>"2015-09-02T08:34:59UTC", :not_after=>"2020-09-01T08:34:59UTC"},
                  "second-active.my.domain" => {:serial => 5, :not_before => "2017-01-14T12:01:22UTC", :not_after => "2022-01-14T12:01:22UTC"}},
                 @puppet_cert.compute_ca_inventory(INVENTORY_CONTENTS, CRL_CONTENTS))
  end

  def test_should_clean_host
    #TODO
    assert_respond_to @puppet_cert, :clean
  end

  def test_should_sign_host
    #TODO
    assert_respond_to @puppet_cert, :sign
  end

end
