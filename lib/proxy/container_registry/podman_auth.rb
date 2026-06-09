# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tmpdir'

module Proxy
  module ContainerRegistry
    # Provides mTLS certificate setup for authenticating podman CLI commands
    # against a Katello container registry using the smart-proxy's existing
    # foreman SSL client certificate (foreman_ssl_cert / foreman_ssl_key).
    #
    # Usage in an async runner (initialize_command pattern):
    #
    #   def start
    #     @cert_dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    #     cmd = "podman push #{Proxy::ContainerRegistry::PodmanAuth.tls_args(@cert_dir)} ..."
    #     initialize_command('bash', '-c', cmd)
    #   end
    #
    #   def close
    #     Proxy::ContainerRegistry::PodmanAuth.cleanup(@cert_dir)
    #   end
    module PodmanAuth
      # Creates a temporary directory with symlinks named as podman expects
      # (client.cert, client.key, ca.crt) pointing at the smart-proxy's
      # existing SSL certificate files. Symlinks are used rather than copies
      # to avoid duplicating the private key on disk.
      # Call cleanup when done.
      def self.setup_cert_dir
        cert_file = Proxy::SETTINGS.foreman_ssl_cert || Proxy::SETTINGS.ssl_certificate
        key_file  = Proxy::SETTINGS.foreman_ssl_key  || Proxy::SETTINGS.ssl_private_key
        ca_file   = Proxy::SETTINGS.foreman_ssl_ca   || Proxy::SETTINGS.ssl_ca_file

        dir = Dir.mktmpdir('podman_registry_cert')
        File.symlink(cert_file, File.join(dir, 'client.cert')) if cert_file.to_s != ''
        File.symlink(key_file,  File.join(dir, 'client.key'))  if key_file.to_s != ''
        File.symlink(ca_file,   File.join(dir, 'ca.crt'))      if ca_file.to_s != ''
        dir
      end

      # Removes the temporary cert directory created by setup_cert_dir.
      def self.cleanup(cert_dir)
        FileUtils.rm_rf(cert_dir) if cert_dir
      end

      # Returns the podman TLS arguments string for use in shell commands.
      def self.tls_args(cert_dir)
        "--tls-verify=true --cert-dir #{Shellwords.escape(cert_dir)}"
      end
    end
  end
end
