require 'test_helper'
require 'tempfile'
require 'fileutils'

require 'puppetca/puppetca'
require 'puppetca/puppetca_certmanager'

class ProxyTest < Test::Unit::TestCase
  CSR_EXAMPLE = <<EOF
-----BEGIN CERTIFICATE REQUEST-----
MIIEdTCCAl0CAQAwGzEZMBcGA1UEAwwQdGVzdC5leGFtcGxlLmNvbTCCAiIwDQYJ
KoZIhvcNAQEBBQADggIPADCCAgoCggIBAK+eSI5LYrBUROs02A9DYPqEpnN1YokD
MSb47NQW0A4+o7B7h/B3HFN2Moo/US/zNLDvHGuVDZIaIpudtNBTBSX0MQPtF8tQ
Lm7WA6wGwqpX3eR3OLXdWR/T4wIvFQ1gvCS/snuW8YennSeAl1Yijtr2EHiPFJ/i
Dy67vGhvXrqVDl/svIf13uw9zcxZ34VfE8zYg5WZ/thlhjbue/KKJdn+riNIYNK4
gwEjFNER9U38UPZUXMNJCEAXEJ7GKXQUKMXXtybp5jihPxTjbxFKilaIEJNM35ej
9Ra0OREGc0Cc0beaW9+n9ZFBxsfM/NV0nzOos4tmSEyAq54Nbd80ropYivrmSRQf
/yDPijvmC4frL1nhSJaf17rmfw27urbPcObbpuQFXCIlNFJd/CwpPds6ikZ9otDx
yTzPveLbQUCh3CzReODC7jopi7vchPH3cZVvuaE90REKL++3xHqOzRpq5tZ1xc2j
3agiQmTthnzABx6cj/q2ab4YAwpaSIAZFoHtzD8tsyD1WTGkL9jzBkCULd7ZcQdR
AL0PwGLYI2hbCsQV6i9noVZZ19+hHEjjk06lG5SKK+H8eTIybWr9IPU/yZowNPtd
et6samT8ltBLAxqTFffrdsTUTQAoN+ykgsML/N3LUuPACg1G6ge0MQVVvBIfCNiP
SjfPJmthHHc1AgMBAAGgFTATBgkqhkiG9w0BCQcxBhMEMTIzNDANBgkqhkiG9w0B
AQsFAAOCAgEAfTtWZAP8z9pxR6esLkoCfhhXaYzjnzJ5/4r+x/VPpJQEzI37CScG
Dma+UzVkIddCVc5oFtzLtVZtGTaygW2QyR7wu+an0qQBs+MVzkjPPnMLerDUR89c
Nk5DlDMaKFYV3JJpg2G2YdmOR0SEF0640Aw0/Ftx41iTSLSFopDMcTPRbZ9zm2AN
uer2TMIWpio6k6OyEJHkyifQOG1kgI+amVgk21kVRm5qUZV01QduLSxuN8KQKDYT
dmE31BpSQdVYzvrRPV558+NiWSrRheQtLfCl4BUZsZjfgh7OXSiy/yCZ6Co7FeDX
WbVtlIeaFukt5fPD4VKBQVIP296ZiB4BFIDLUcq87DaWbjbO1owS/B89MbAM6Fjy
FHCE3x0nUev3LYrKrJGouHYXiyUNGQk1ilI60y1xc3+B3ErjzpszJB1uBRk1fsem
Np60VUVqNPD7GzxlE/acgEa2Xij1vl+g4yIjWGVv5Fokb4fO6K+n8iSEYKG4+nMr
+vjP7bTcW4GymYPH38TtQfzhXvFMODL8ehiy2xjndEfLMitrbP1vjiLrCZD6gIk3
alxj7nHJMXF83Rqg/7OhERMVmUGE+tDiRD95bMK/eYq4sj49zke6puf5r0MeW6Fv
jfuZ0r0kJmJF/r2FZEKuScl0uS4/RWUvgUdUFwpZ3i8KzJWJ6NDm7eY=
-----END CERTIFICATE REQUEST-----
EOF

  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    @cert_manager = Proxy::PuppetCa::Certmanager.new
  end

  def test_extracts_token_form_csr
    req = Proxy::PuppetCa::CSR.new CSR_EXAMPLE
    assert_equal req.challenge_password, '1234'
  end

  def test_acceptsall_on_signall
    @cert_manager.stubs(:sign_all).returns(true)
    assert_true @cert_manager.autosign CSR_EXAMPLE
  end

  def test_makes_a_correct_foreman_call
    stub_request(:delete, @foreman_url+'/api/puppetca_token/test').to_return(:status => [204, 'NO CONTENT'])
    assert_true @cert_manager.foreman_csr_validation 'test'
  end

  def test_handles_foreman_deny_correct
    stub_request(:delete, @foreman_url+'/api/puppetca_token/1234').to_return(:status => [404, 'NOT FOUND'])
    assert_false @cert_manager.autosign CSR_EXAMPLE
  end

  def test_handles_foreman_accept_correct
    stub_request(:delete, @foreman_url+'/api/puppetca_token/1234').to_return(:status => [204, 'NO CONTENT'])
    assert_true @cert_manager.autosign CSR_EXAMPLE
  end

  def test_which_should_return_a_binary_path
    ENV.stubs(:[]).with('PATH').returns(['/foo', '/bin', '/usr/bin'].join(File::PATH_SEPARATOR))
    { '/foo' => false, '/bin' => true, '/usr/bin' => false, '/usr/sbin' => false, '/usr/local/bin' => false, '/usr/local/sbin' => false }.each do |p,r|
      FileTest.stubs(:file?).with("#{p}/ls").returns(r)
      FileTest.stubs(:executable?).with("#{p}/ls").returns(r)
    end
    assert_equal '/bin/ls', @cert_manager.which('ls')
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
                 @cert_manager.parse_inventory(INVENTORY_CONTENTS))
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
   assert_equal Set.new([2, 4]), @cert_manager.revoked_serials(CRL_CONTENTS)
  end

  def test_compute_ca_inventory
    assert_equal({"revoked.my.domain"=>{:serial=>4, :not_before=>"2017-01-11T15:04:35UTC", :not_after=>"2022-01-11T15:04:35UTC", :state=>"revoked"},
                  "active.my.domain"=>{:serial=>3, :not_before=>"2015-09-02T08:34:59UTC", :not_after=>"2020-09-01T08:34:59UTC"},
                  "second-active.my.domain" => {:serial => 5, :not_before => "2017-01-14T12:01:22UTC", :not_after => "2022-01-14T12:01:22UTC"}},
                 @cert_manager.compute_ca_inventory(INVENTORY_CONTENTS, CRL_CONTENTS))
  end

  def test_should_clean_host
    #TODO
    assert_respond_to @cert_manager, :clean
  end

  def test_should_sign_host
    #TODO
    assert_respond_to @cert_manager, :sign
  end

end
