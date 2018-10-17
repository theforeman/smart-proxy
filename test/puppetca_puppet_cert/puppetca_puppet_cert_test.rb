require 'test_helper'
require 'tempfile'
require 'fileutils'

require 'puppetca/puppetca'
require 'puppetca_puppet_cert/puppetca_puppet_cert'
require 'puppetca_puppet_cert/puppetca_impl'

class PuppetCaPuppetCertImplTest < Test::Unit::TestCase
  def setup
    @puppet_cert = Proxy::PuppetCa::PuppetcaPuppetCert::PuppetcaImpl.new
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

 PUPPET_CERT_LIST_OUTPUT = <<OUTPUT
+ "tfmcentos7.beispiel.xyz" (SHA256) B1:7C:A8:EC:2A:37:E6:2D:A6:55:B9:00:DE:2B:36:6B:E1:F0:BA:49:42:91:3D:60:4B:42:81:6F:5E:18:78:C8
+ "tfmdemo.beispiel.xyz"    (SHA256) 79:E3:98:2C:FF:53:74:02:6F:96:6D:61:05:85:1A:5F:C6:FB:67:AF:A6:05:24:FA:16:42:21:14:46:86:AC:AF (alt names: "DNS:puppet", "DNS:puppet.beispiel.xyz", "DNS:tfmdemo.beispiel.xyz")
OUTPUT

PUPPET_CERT_CLEAN_OUTPUT = <<OUTPUT
Notice: Revoked certificate with serial 4
Notice: Removing file Puppet::SSL::Certificate tfmcentos7.beispiel.xyz at '/etc/puppetlabs/puppet/ssl/ca/signed/tfmcentos7.beispiel.xyz.pem'
Notice: Removing file Puppet::SSL::Certificate tfmcentos7.beispiel.xyz at '/etc/puppetlabs/puppet/ssl/certs/tfmcentos7.beispiel.xyz.pem'
OUTPUT

PUPPET_CERT_SIGN_OUTPUT = <<OUTPUT
Signing Certificate Request for:
  "tfmcentos7.beispiel.xyz" (SHA256) 23:B0:F0:83:72:ED:69:8A:E1:06:83:0E:A6:DE:0B:5D:83:0B:58:3B:AB:EE:82:F1:30:1B:39:19:84:5B:4B:10 **
Notice: Signed certificate request for tfmcentos7.beispiel.xyz
Notice: Removing file Puppet::SSL::CertificateRequest tfmcentos7.beispiel.xyz at '/etc/puppetlabs/puppet/ssl/ca/requests/tfmcentos7.beispiel.xyz.pem'
OUTPUT

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
    @puppet_cert.stubs(:find_puppetca)
    @puppet_cert.instance_variable_set('@puppetca', '/tmp/puppet cert')
    @puppet_cert.instance_variable_set('@sudo', '')
    @puppet_cert.stubs('`').with(' /tmp/puppet cert --clean tfmcentos7.beispiel.xyz 2>&1').returns(PUPPET_CERT_CLEAN_OUTPUT)

    assert @puppet_cert.clean('tfmcentos7.beispiel.xyz')
  end

  def test_should_sign_host
    @puppet_cert.stubs(:find_puppetca)
    @puppet_cert.instance_variable_set('@puppetca', '/tmp/puppet cert')
    @puppet_cert.instance_variable_set('@sudo', '')
    @puppet_cert.stubs('`').with(' /tmp/puppet cert --sign tfmcentos7.beispiel.xyz 2>&1').returns(PUPPET_CERT_SIGN_OUTPUT)

    assert @puppet_cert.sign('tfmcentos7.beispiel.xyz')
  end

  def test_should_list_certs
    @puppet_cert.stubs(:find_puppetca)
    @puppet_cert.stubs(:ssldir).returns(File.expand_path(File.join(File.dirname(__FILE__), '.', 'fixtures')))
    @puppet_cert.instance_variable_set('@puppetca', '/tmp/puppet cert')
    @puppet_cert.stubs('`').with(' /tmp/puppet cert --list --all').returns(PUPPET_CERT_LIST_OUTPUT)
    Process::Status.any_instance.stubs(:exitstatus).returns(0)

    expected = {
      'Puppet' => {
        :not_after => '2023-06-09T09:30:19UTC',
        :not_before => '2018-06-09T09:30:19UTC',
        :serial => 1
      },
      'tfmcentos7.beispiel.xyz' =>
      {
        :fingerprint => 'SHA256',
        :not_after => '2023-09-12T17:31:00UTC',
        :not_before => '2018-09-12T17:31:00UTC',
        :serial => 4,
        :state => 'valid'
      },
      'tfmdemo.beispiel.xyz' => {
        :fingerprint => 'SHA256',
        :not_after => '2023-06-09T09:30:21UTC',
        :not_before => '2018-06-09T09:30:21UTC',
        :serial => 2,
        :state => 'valid'
      }
    }

    assert_equal expected, @puppet_cert.list
  end

  def test_find_puppetca_without_sudo
    stub_puppetca_executables

    @puppet_cert.stubs(:use_sudo?).returns(false)
    @puppet_cert.find_puppetca
    puppetca = @puppet_cert.instance_variable_get('@puppetca')
    sudo = @puppet_cert.instance_variable_get('@sudo')
    assert_equal "#{@ssldir}/puppet --ssldir #{@ssldir}", puppetca
    assert_equal '', sudo
  end

  def test_find_puppetca_with_sudo
    stub_puppetca_executables

    @puppet_cert.stubs(:use_sudo?).returns(true)
    @puppet_cert.find_puppetca
    puppetca = @puppet_cert.instance_variable_get('@puppetca')
    sudo = @puppet_cert.instance_variable_get('@sudo')
    assert_equal "#{@ssldir}/puppet --ssldir #{@ssldir}", puppetca
    assert_equal "#{@ssldir}/sudo -S", sudo
  end

  def test_find_puppetca_with_sudo_command
    stub_puppetca_executables

    @puppet_cert.stubs(:use_sudo?).returns(true)
    @puppet_cert.stubs(:sudo_command).returns("#{@ssldir}/sudo")
    @puppet_cert.find_puppetca
    puppetca = @puppet_cert.instance_variable_get('@puppetca')
    sudo = @puppet_cert.instance_variable_get('@sudo')
    assert_equal "#{@ssldir}/puppet --ssldir #{@ssldir}", puppetca
    assert_equal "#{@ssldir}/sudo -S", sudo
  end

  private

  def stub_puppetca_executables
    @ssldir = File.expand_path(File.join(File.dirname(__FILE__), '.', 'fixtures'))
    @puppet_cert.stubs(:ssldir).returns(@ssldir)

    @puppet_cert.stubs(:which).with('puppetca', anything).returns(nil)
    @puppet_cert.stubs(:which).with('puppet', anything).returns(File.join(@ssldir, 'puppet'))
    @puppet_cert.stubs(:which).with('sudo').returns(File.join(@ssldir, 'sudo'))
  end
end
