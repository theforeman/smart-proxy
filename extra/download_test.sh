#!/usr/bin/env bash

set -euo pipefail

PROXY_URL="http://127.0.0.1:8000"

# CentOS 10 Stream
curl --fail --silent --show-error \
  --header 'Content-Type: application/json' \
  --data '{
  "extract": {
    "source": "https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/images/boot.iso",
    "destination": "bootloader-universe/pxegrub2/centos_stream/10/x86_64/boot.iso",
    "type": "iso",
    "files": {
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/grubx64.efi": "EFI/BOOT/grubx64.efi",
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/shimx64.efi": "EFI/BOOT/BOOTX64.EFI",
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/vmlinuz": "images/pxeboot/vmlinuz",
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/initrd.img": "images/pxeboot/initrd.img"
    },
    "symlinks": {
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/boot.efi": "bootloader-universe/pxegrub2/centos_stream/10/x86_64/grubx64.efi",
      "bootloader-universe/pxegrub2/centos_stream/10/x86_64/boot-sb.efi": "bootloader-universe/pxegrub2/centos_stream/10/x86_64/shimx64.efi"
    }
  }
}' \
  "${PROXY_URL}/tftp/fetch_and_process"

# Debian 12 (Bookworm)
curl --fail --silent --show-error \
  --header 'Content-Type: application/json' \
  --data '{
  "extract": {
    "source": "https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/netboot.tar.gz",
    "destination": "bootloader-universe/pxegrub2/debian/12/x86_64/netboot.tar.gz",
    "type": "tgz",
    "files": {
      "bootloader-universe/pxegrub2/debian/12/x86_64/linux": "debian-installer/amd64/linux",
      "bootloader-universe/pxegrub2/debian/12/x86_64/initrd.gz": "debian-installer/amd64/initrd.gz",
      "bootloader-universe/pxegrub2/debian/12/x86_64/grubx64.efi": "debian-installer/amd64/grubx64.efi",
      "bootloader-universe/pxegrub2/debian/12/x86_64/shimx64.efi": "debian-installer/amd64/bootnetx64.efi"
    },
    "symlinks": {
      "bootloader-universe/pxegrub2/debian/12/x86_64/boot.efi": "bootloader-universe/pxegrub2/debian/12/x86_64/grubx64.efi",
      "bootloader-universe/pxegrub2/debian/12/x86_64/boot-sb.efi": "bootloader-universe/pxegrub2/debian/12/x86_64/shimx64.efi"
    }
  }
}' \
  "${PROXY_URL}/tftp/fetch_and_process"

# Ubuntu 26.04
curl --fail --silent --show-error \
  --header 'Content-Type: application/json' \
  --data '{
  "extract": {
    "source": "https://releases.ubuntu.com/26.04/ubuntu-26.04-netboot-amd64.tar.gz",
    "destination": "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/netboot.tar.gz",
    "type": "tgz",
    "files": {
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/linux": "amd64/linux",
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/initrd.gz": "amd64/initrd",
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/grubx64.efi": "amd64/grubx64.efi",
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/shimx64.efi": "amd64/bootx64.efi"
    },
    "symlinks": {
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/boot.efi": "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/grubx64.efi",
      "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/boot-sb.efi": "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/shimx64.efi"
    }
  }
}' \
  "${PROXY_URL}/tftp/fetch_and_process"

# Ubuntu ISO is also needed
curl --fail --silent --show-error \
  --header 'Content-Type: application/json' \
  --data '{
  "source": "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso",
  "destination": "bootloader-universe/pxegrub2/ubuntu/26.04/x86_64/boot.iso"
}' \
  "${PROXY_URL}/tftp/fetch_and_process"
