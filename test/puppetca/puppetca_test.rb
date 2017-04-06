require 'test_helper'
require 'tempfile'
require 'fileutils'

require 'puppetca/puppetca'
require 'puppetca/puppetca_main'

class ProxyTest < Test::Unit::TestCase
  ## Helper for autosign files.
  def create_temp_autosign_file
    file = Tempfile.new('autosign_test')
    begin
      ## Setup
      FileUtils.cp './test/fixtures/autosign.conf', file.path
      Proxy::PuppetCa.stubs(:autosign_file).returns(file.path)
    rescue
      file.close
      file.unlink
      file = nil
    end
    file
  end

  def test_should_list_autosign_entries
    Proxy::PuppetCa.stubs(:autosign_file).returns('./test/fixtures/autosign.conf')
    assert_equal Proxy::PuppetCa.autosign_list, ['foo.example.com', '*.bar.example.com']
  end

  def test_should_add_autosign_entry
    file = create_temp_autosign_file
    content = []
    begin
      ## Execute
      Proxy::PuppetCa.autosign 'foobar.example.com'
      ## Read output
      content = file.read.split("\n")
    ensure
      file.close
      file.unlink
    end
    assert_true content.include?('foobar.example.com')
  end

  def test_should_not_duplicate_autosign_entry
    file = create_temp_autosign_file
    begin
      before_content = file.read
      file.seek(0)
      ## Execute
      Proxy::PuppetCa.autosign 'foo.example.com'
      ## Read output
      after_content = file.read
    ensure
      file.close
      file.unlink
    end
    assert_equal before_content, after_content
  end

  def test_should_remove_autosign_entry
    file = create_temp_autosign_file
    begin
      Proxy::PuppetCa.disable 'foo.example.com'
      content = file.read
    ensure
      file.close
      file.unlink
    end
    assert_false content.split("\n").include?('foo.example.com')
    assert_true content.end_with?("\n")
  end

  def test_which_should_return_a_binary_path
    ENV.stubs(:[]).with('PATH').returns(['/foo', '/bin', '/usr/bin'].join(File::PATH_SEPARATOR))
    { '/foo' => false, '/bin' => true, '/usr/bin' => false, '/usr/sbin' => false, '/usr/local/bin' => false, '/usr/local/sbin' => false }.each do |p,r|
      FileTest.stubs(:file?).with("#{p}/ls").returns(r)
      FileTest.stubs(:executable?).with("#{p}/ls").returns(r)
    end
    assert_equal '/bin/ls', Proxy::PuppetCa.which('ls')
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
                 ::Proxy::PuppetCa.parse_inventory(INVENTORY_CONTENTS))
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
   assert_equal Set.new([2, 4]), ::Proxy::PuppetCa.revoked_serials(CRL_CONTENTS)
  end

  def test_compute_ca_inventory
    assert_equal({"revoked.my.domain"=>{:serial=>4, :not_before=>"2017-01-11T15:04:35UTC", :not_after=>"2022-01-11T15:04:35UTC", :state=>"revoked"},
                  "active.my.domain"=>{:serial=>3, :not_before=>"2015-09-02T08:34:59UTC", :not_after=>"2020-09-01T08:34:59UTC"},
                  "second-active.my.domain" => {:serial => 5, :not_before => "2017-01-14T12:01:22UTC", :not_after => "2022-01-14T12:01:22UTC"}},
                 ::Proxy::PuppetCa.compute_ca_inventory(INVENTORY_CONTENTS, CRL_CONTENTS))
  end

  def test_should_clean_host
    #TODO
    assert_respond_to Proxy::PuppetCa, :clean
  end

  def test_should_disable_host
    #TODO
    assert_respond_to Proxy::PuppetCa, :disable
  end

  def test_should_sign_host
    #TODO
    assert_respond_to Proxy::PuppetCa, :sign
  end

end
