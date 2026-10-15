require 'test_helper'
require 'launcher'
require 'tempfile'

class LauncherTest < Test::Unit::TestCase
  def setup
    @launcher = Proxy::Launcher.new
  end

  def test_install_webrick_callback
    app1 = {app: 1}
    app2 = {app: 2}
    @launcher.install_webrick_callback!(app1, nil, app2)
    @launcher.expects(:launched).never
    app1[:StartCallback].call
    @launcher.expects(:launched).with([app1, app2])
    app2[:StartCallback].call
  end

  def test_launched_with_sdnotify
    @launcher.logger.expects(:info).with(includes('2 socket(s)'))
    ::SdNotify.expects(:ready)
    @launcher.launched([:app1, :app2])
  end
end

class LauncherHostAuthorizationTest < Test::Unit::TestCase
  def test_warns_when_permitted_hosts_are_not_enforced
    settings = Proxy::Settings::Global.new(permitted_hosts: ['proxy.example.com'])
    launcher = Proxy::Launcher.new(settings)
    ::Sinatra::Base.expects(:respond_to?).with(:setup_host_authorization, true).returns(false)
    launcher.logger.expects(:warn).with('permitted_hosts is configured but not enforced by this Sinatra version')

    launcher.warn_if_unsupported_host_authorization
  end

  def test_no_warning_when_host_authorization_is_supported
    settings = Proxy::Settings::Global.new(permitted_hosts: ['proxy.example.com'])
    launcher = Proxy::Launcher.new(settings)
    ::Sinatra::Base.expects(:respond_to?).with(:setup_host_authorization, true).returns(true)
    launcher.logger.expects(:warn).never

    launcher.warn_if_unsupported_host_authorization
  end

  def test_no_warning_when_permitted_hosts_are_empty
    settings = Proxy::Settings::Global.new(permitted_hosts: [])
    launcher = Proxy::Launcher.new(settings)
    launcher.logger.expects(:warn).never

    launcher.warn_if_unsupported_host_authorization
  end
end

class LauncherTlsCiphersTest < Test::Unit::TestCase
  def setup
    @launcher = Proxy::Launcher.new
  end

  def launcher_with(settings_hash)
    settings = Proxy::Settings::Global.new(settings_hash)
    Proxy::Launcher.new(settings)
  end

  def test_resolve_tls_ciphers_returns_configured_value
    launcher = launcher_with(tls_ciphers: 'HIGH:!aNULL')
    assert_equal 'HIGH:!aNULL', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_returns_nil_for_empty_string
    launcher = launcher_with(tls_ciphers: '')
    assert_nil launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_raises_on_non_string
    launcher = launcher_with(tls_ciphers: 12)
    error = assert_raises(RuntimeError) { launcher.resolve_tls_ciphers }
    assert_match(/Invalid tls_ciphers value/, error.message)
    assert_match(/must be a String/, error.message)
  end

  def test_resolve_tls_ciphers_autodetects_profile_system_when_crypto_policies_present
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(true)
    launcher.logger.stubs(:info)
    assert_equal 'PROFILE=SYSTEM', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_defaults_to_high_when_no_crypto_policies
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(false)
    launcher.logger.stubs(:debug)
    assert_equal 'HIGH', launcher.resolve_tls_ciphers
  end

  def test_validate_tls_ciphers_returns_nil_pair_for_nil
    assert_equal [nil, nil], @launcher.validate_tls_ciphers!(nil)
  end

  def test_validate_tls_ciphers_returns_tls12_only_for_tls12_cipher_string
    tls12, tls13 = @launcher.validate_tls_ciphers!('HIGH')
    assert_equal 'HIGH', tls12
    assert_nil tls13
  end

  def test_validate_tls_ciphers_warns_when_profile_system_and_tls_min_version_set
    launcher = launcher_with(tls_min_version: '1.2')
    launcher.logger.expects(:warn).with(regexp_matches(/PROFILE=SYSTEM/))
    launcher.validate_tls_ciphers!('PROFILE=SYSTEM')
  end

  def test_validate_tls_ciphers_raises_when_tls12_only_cipher_string_and_min_version_tls13
    launcher = launcher_with(tls_ciphers: 'HIGH', tls_min_version: '1.3')
    error = assert_raises(RuntimeError) { launcher.validate_tls_ciphers!('HIGH') }
    assert_match(/1\.3/, error.message)
  end

  def test_validate_tls_ciphers_does_not_raise_when_min_version_tls13_and_tls_ciphers_unset
    launcher = launcher_with(tls_min_version: '1.3')
    File.stubs(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(false)
    launcher.logger.stubs(:debug)
    assert_nothing_raised { launcher.validate_tls_ciphers!(launcher.resolve_tls_ciphers) }
  end

  def test_validate_tls_ciphers_warns_when_ciphersuites_method_absent_and_tls_ciphers_set
    launcher = launcher_with(tls_ciphers: 'HIGH')
    OpenSSL::SSL::SSLContext.stubs(:method_defined?).with(:ciphersuites=).returns(false)
    launcher.logger.expects(:warn).with(regexp_matches(/ciphersuites=/))
    cipher_list, ciphersuites = launcher.validate_tls_ciphers!('HIGH')
    assert_equal 'HIGH', cipher_list
    assert_nil ciphersuites
  end

  def test_validate_tls_ciphers_does_not_warn_when_ciphersuites_method_absent_and_tls_ciphers_unset
    launcher = launcher_with({})
    OpenSSL::SSL::SSLContext.stubs(:method_defined?).with(:ciphersuites=).returns(false)
    launcher.logger.expects(:warn).never
    cipher_list, ciphersuites = launcher.validate_tls_ciphers!('HIGH')
    assert_equal 'HIGH', cipher_list
    assert_nil ciphersuites
  end
end

class LauncherTlsMinVersionTest < Test::Unit::TestCase
  def test_resolve_tls_min_version_raises_on_invalid_version
    settings = Proxy::Settings::Global.new(tls_min_version: '1.4')
    launcher = Proxy::Launcher.new(settings)
    error = assert_raises(RuntimeError) { launcher.resolve_tls_min_version }
    assert_match(/Invalid tls_min_version/, error.message)
    assert_match(/1\.4/, error.message)
  end

  def test_resolve_tls_min_version_returns_constant_on_valid_version
    settings = Proxy::Settings::Global.new(tls_min_version: '1.3')
    launcher = Proxy::Launcher.new(settings)
    launcher.logger.stubs(:info)
    assert_equal OpenSSL::SSL::TLS1_3_VERSION, launcher.resolve_tls_min_version
  end

  def test_resolve_tls_min_version_returns_nil_when_not_configured
    settings = Proxy::Settings::Global.new({})
    launcher = Proxy::Launcher.new(settings)
    assert_nil launcher.resolve_tls_min_version
  end
end

class LauncherWebrickSslTest < Test::Unit::TestCase
  def setup
    cert, key = WEBrick::Utils.create_self_signed_cert(2048, [['CN', 'test']], 'test')
    @ssl_app = {
      :SSLEnable      => true,
      :SSLPrivateKey  => key,
      :SSLCertificate => cert,
      :DoNotListen    => true,
      :Logger         => WEBrick::Log.new(::File::NULL),
      :AccessLog      => [],
    }
    @launcher = Proxy::Launcher.new
    ::WEBrick::HTTPServer.any_instance.stubs(:mount)
  end

  def test_webrick_server_applies_ssl_min_version
    @ssl_app[:SSLMinVersion] = OpenSSL::SSL::TLS1_3_VERSION
    server = @launcher.webrick_server(@ssl_app, [], 8443)
    assert_equal OpenSSL::SSL::TLS1_3_VERSION,
                 server.ssl_context.instance_variable_get(:@min_proto_version)
  end

  def test_webrick_server_does_not_apply_ssl_min_version_when_absent
    server = @launcher.webrick_server(@ssl_app, [], 8443)
    assert_nil server.ssl_context.instance_variable_get(:@min_proto_version)
  end

  def test_webrick_server_applies_ciphersuites_when_ssl_ciphersuites_set
    @ssl_app[:SSLCiphersuites] = 'PROFILE=SYSTEM'
    OpenSSL::SSL::SSLContext.any_instance.expects(:ciphersuites=).with('PROFILE=SYSTEM')
    @launcher.webrick_server(@ssl_app, [], 8443)
  end

  def test_webrick_server_skips_ciphersuites_when_ssl_ciphersuites_absent
    OpenSSL::SSL::SSLContext.any_instance.expects(:ciphersuites=).never
    @launcher.webrick_server(@ssl_app, [], 8443)
  end
end

class LauncherSslCipherTest < Test::Unit::TestCase
  SSL_FIXTURES = File.expand_path(File.join(__dir__, 'fixtures', 'ssl')).freeze

  def launcher_with_cipher(cipher)
    settings = Proxy::Settings::Global.new(
      tls_ciphers: cipher,
      ssl_private_key: File.join(SSL_FIXTURES, 'private_keys', 'server.example.com.pem'),
      ssl_certificate: File.join(SSL_FIXTURES, 'certs', 'server.example.com.pem'),
      ssl_ca_file:     File.join(SSL_FIXTURES, 'certs', 'ca.pem')
    )
    Proxy::Launcher.new(settings)
  end

  def test_server_raises_on_invalid_cipher_string
    launcher = launcher_with_cipher('NOT_A_VALID_CIPHER_STRING!!!')
    app = launcher.https_app(0, [])
    error = assert_raises(RuntimeError) do
      launcher.webrick_server(app.merge(AccessLog: [Logger.new('/dev/null')]), ['localhost'], 0)
    end
    assert_match(/NOT_A_VALID_CIPHER_STRING!!!/, error.message)
  end
end

class LauncherSslCertificateTest < Test::Unit::TestCase
  def setup
    @launcher = Proxy::Launcher.new
    @launcher.logger
    @root = generate_ca('Test Root CA', 1)
    @intermediate = generate_ca('Test Intermediate CA', 2, @root)
    @leaf = generate_leaf('localhost', 3, @intermediate)
  end

  def test_load_ssl_certificates_single_cert
    Tempfile.create(['cert', '.pem']) do |f|
      f.write(@leaf[0].to_pem)
      f.flush
      certs = @launcher.load_ssl_certificates(f.path)
      assert_equal 1, certs.size
      assert_equal @leaf[0].subject.to_s, certs[0].subject.to_s
    end
  end

  def test_load_ssl_certificates_fullchain
    Tempfile.create(['fullchain', '.pem']) do |f|
      f.write(@leaf[0].to_pem)
      f.write(@intermediate[0].to_pem)
      f.write(@root[0].to_pem)
      f.flush
      certs = @launcher.load_ssl_certificates(f.path)
      assert_equal 3, certs.size
      assert_equal @leaf[0].subject.to_s, certs[0].subject.to_s
      assert_equal @intermediate[0].subject.to_s, certs[1].subject.to_s
      assert_equal @root[0].subject.to_s, certs[2].subject.to_s
    end
  end

  def test_load_ssl_certificates_empty_file_raises
    Tempfile.create(['empty', '.pem']) do |f|
      f.flush
      assert_raises(OpenSSL::X509::CertificateError) { @launcher.load_ssl_certificates(f.path) }
    end
  end

  def test_load_ssl_certificates_unreadable_file_raises
    assert_raises(Errno::ENOENT) { @launcher.load_ssl_certificates('/nonexistent/cert.pem') }
  end

  def test_https_app_sets_extra_chain_cert_with_fullchain
    Tempfile.create(['fullchain', '.pem']) do |chain_f|
      Tempfile.create(['key', '.pem']) do |key_f|
        chain_f.write(@leaf[0].to_pem)
        chain_f.write(@intermediate[0].to_pem)
        chain_f.flush
        key_f.write(@leaf[1].to_pem)
        key_f.flush

        settings = Proxy::Settings::Global.new(
          ssl_certificate: chain_f.path,
          ssl_private_key: key_f.path,
          ssl_ca_file: chain_f.path
        )
        launcher = Proxy::Launcher.new(settings)
        launcher.stubs(:resolve_tls_ciphers).returns(nil)

        app = launcher.https_app(0, [])
        assert_equal 1, app[:SSLExtraChainCert].size
        assert_equal @intermediate[0].subject.to_s, app[:SSLExtraChainCert][0].subject.to_s
      end
    end
  end

  def test_https_app_omits_extra_chain_cert_with_single_cert
    Tempfile.create(['single', '.pem']) do |cert_f|
      Tempfile.create(['key', '.pem']) do |key_f|
        cert_f.write(@leaf[0].to_pem)
        cert_f.flush
        key_f.write(@leaf[1].to_pem)
        key_f.flush

        settings = Proxy::Settings::Global.new(
          ssl_certificate: cert_f.path,
          ssl_private_key: key_f.path,
          ssl_ca_file: cert_f.path
        )
        launcher = Proxy::Launcher.new(settings)
        launcher.stubs(:resolve_tls_ciphers).returns(nil)

        app = launcher.https_app(0, [])
        assert_nil app[:SSLExtraChainCert]
      end
    end
  end

  def test_load_file_api_is_preferred
    OpenSSL::X509::Certificate.expects(:load_file).with('chain.pem').returns([@leaf[0], @intermediate[0]])
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(true)
    assert_equal [@leaf[0], @intermediate[0]], @launcher.load_ssl_certificates('chain.pem')
  end

  def test_load_api_is_used_when_load_file_is_unavailable
    added_load = !OpenSSL::X509::Certificate.respond_to?(:load)
    OpenSSL::X509::Certificate.define_singleton_method(:load) { |_data| [] } if added_load
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(false)
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load).returns(true)
    File.expects(:binread).with('chain.pem').returns('PEM data')
    OpenSSL::X509::Certificate.expects(:load).with('PEM data').returns([@leaf[0], @intermediate[0]])
    assert_equal [@leaf[0], @intermediate[0]], @launcher.load_ssl_certificates('chain.pem')
  ensure
    OpenSSL::X509::Certificate.unstub(:load)
    OpenSSL::X509::Certificate.singleton_class.send(:remove_method, :load) if added_load
  end

  def test_fallback_preserves_certificate_order
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(false)
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load).returns(false)
    File.expects(:binread).with('chain.pem').returns(@leaf[0].to_pem + @intermediate[0].to_pem)
    assert_equal [@leaf[0].to_der, @intermediate[0].to_der], @launcher.load_ssl_certificates('chain.pem').map(&:to_der)
  end

  def test_fallback_loads_der_certificate
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(false)
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load).returns(false)
    Tempfile.create(['certificate', '.der']) do |f|
      f.binmode
      f.write(@leaf[0].to_der)
      f.flush
      certs = @launcher.load_ssl_certificates(f.path)
      assert_equal [@leaf[0].to_der], certs.map(&:to_der)
    end
  end

  def test_fallback_rejects_invalid_der
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(false)
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load).returns(false)
    Tempfile.create(['invalid', '.der']) do |f|
      f.binmode
      f.write(@leaf[0].to_der[0, 20])
      f.flush
      assert_raises(OpenSSL::X509::CertificateError) { @launcher.load_ssl_certificates(f.path) }
    end
  end

  def test_malformed_certificate_raises
    Tempfile.create(['malformed', '.pem']) do |f|
      f.write("-----BEGIN CERTIFICATE-----\ninvalid\n-----END CERTIFICATE-----\n")
      f.flush
      assert_raises(OpenSSL::X509::CertificateError) { @launcher.load_ssl_certificates(f.path) }
    end
  end

  def test_fallback_rejects_truncated_intermediate
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load_file).returns(false)
    OpenSSL::X509::Certificate.stubs(:respond_to?).with(:load).returns(false)
    File.expects(:binread).with('chain.pem').returns(@leaf[0].to_pem + "-----BEGIN CERTIFICATE-----\ntruncated")
    assert_raises(OpenSSL::X509::CertificateError) { @launcher.load_ssl_certificates('chain.pem') }
  end

  def test_launcher_serves_chain_to_root_only_client
    require 'socket'
    require 'timeout'
    Tempfile.create(['fullchain', '.pem']) do |cert_f|
      Tempfile.create(['key', '.pem']) do |key_f|
        cert_f.write(@leaf[0].to_pem + @intermediate[0].to_pem)
        cert_f.flush
        key_f.write(@leaf[1].to_pem)
        key_f.flush
        settings = Proxy::Settings::Global.new(ssl_certificate: cert_f.path,
                                               ssl_private_key: key_f.path,
                                               ssl_ca_file: cert_f.path, tls_ciphers: '')
        launcher = Proxy::Launcher.new(settings)
        app = launcher.https_app(0, []).merge(AccessLog: [Logger.new('/dev/null')])
        server = launcher.webrick_server(app, ['127.0.0.1'], 0)
        port = server.listeners.first.addr[1]
        thread = Thread.new { server.start }
        begin
          context = OpenSSL::SSL::SSLContext.new
          context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          context.cert_store = OpenSSL::X509::Store.new
          context.cert_store.add_cert(@root[0])
          Timeout.timeout(5) do
            TCPSocket.open('127.0.0.1', port) do |tcp|
              ssl = OpenSSL::SSL::SSLSocket.new(tcp, context)
              begin
                ssl.hostname = 'localhost'
                ssl.connect
                ssl.post_connection_check('localhost')
                assert_equal [@leaf[0].to_der, @intermediate[0].to_der], ssl.peer_cert_chain.map(&:to_der)
              ensure
                ssl.close
              end
            end
          end
        ensure
          server.shutdown
          thread.join(5)
          thread.kill if thread.alive?
        end
      end
    end
  end

  private

  def generate_ca(cname, serial, issuer = nil)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = serial
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{cname}")
    cert.issuer = issuer ? issuer[0].subject : cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = issuer ? issuer[0] : cert
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
    cert.add_extension(ef.create_extension('keyUsage', 'keyCertSign,cRLSign', true))
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash'))
    cert.sign(issuer ? issuer[1] : key, OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end

  def generate_leaf(cname, serial, issuer)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = serial
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{cname}")
    cert.issuer = issuer[0].subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = Time.now + 3600
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = issuer[0]
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:FALSE', true))
    cert.add_extension(ef.create_extension('keyUsage', 'digitalSignature,keyEncipherment', true))
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash'))
    cert.add_extension(ef.create_extension('subjectAltName', "DNS:#{cname}"))
    cert.sign(issuer[1], OpenSSL::Digest.new('SHA256'))
    [cert, key]
  end
end
