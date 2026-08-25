require 'test_helper'
require 'launcher'

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
    launcher.stubs(:cipher_string_supported?).with('PROFILE=SYSTEM').returns(true)
    launcher.logger.stubs(:info)
    assert_equal 'PROFILE=SYSTEM', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_defaults_to_high_when_no_crypto_policies
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(false)
    launcher.logger.stubs(:debug)
    assert_equal 'HIGH', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_falls_back_to_parsed_cipher_string_when_profile_system_unsupported
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(true)
    launcher.stubs(:cipher_string_supported?).with('PROFILE=SYSTEM').returns(false)
    launcher.stubs(:crypto_policies_cipher_string).returns('HIGH:!aNULL')
    launcher.stubs(:cipher_string_supported?).with('HIGH:!aNULL').returns(true)
    launcher.logger.stubs(:info)
    assert_equal 'HIGH:!aNULL', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_falls_back_to_high_when_crypto_policies_unparseable
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(true)
    launcher.stubs(:cipher_string_supported?).with('PROFILE=SYSTEM').returns(false)
    launcher.stubs(:crypto_policies_cipher_string).returns(nil)
    launcher.logger.stubs(:warn)
    assert_equal 'HIGH', launcher.resolve_tls_ciphers
  end

  def test_resolve_tls_ciphers_falls_back_to_high_when_parsed_cipher_string_also_unsupported
    launcher = launcher_with({})
    File.expects(:exist?).with(CRYPTO_POLICIES_CONFIG).returns(true)
    launcher.stubs(:cipher_string_supported?).with('PROFILE=SYSTEM').returns(false)
    launcher.stubs(:crypto_policies_cipher_string).returns('BOGUS')
    launcher.stubs(:cipher_string_supported?).with('BOGUS').returns(false)
    launcher.logger.stubs(:warn)
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
