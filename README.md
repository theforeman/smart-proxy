[Smart Proxy](https://projects.theforeman.org/projects/smart-proxy/wiki) is a free open source project that provides restful API to subsystems such as DNS, DHCP, etc, for higher level orchestration tools such as [Foreman](https://github.com/theforeman/foreman).

* Issues: [Redmine](https://projects.theforeman.org/projects/smart-proxy/issues)
* Wiki: [Foreman wiki](https://projects.theforeman.org/projects/smart-proxy/wiki)
* Community and support: We have a [forum](https://community.theforeman.org) and use [Libera](https://libera.chat) IRC channels
    * #theforeman for general support
    * #theforeman-dev for development chat

# Supported Modules
Currently Supported modules:
 * BMC - BMC management of devices supported by freeipmi and ipmitool
 * DHCP - ISC DHCP and MS DHCP Servers
 * DNS - Bind and MS DNS Servers
 * Puppet - Any Puppet server from 4.4, 6+ recommended
 * Puppet CA - Manage certificate signing, cleaning and autosign on a Puppet CA server
 * Realm - Manage host registration to a realm (e.g. FreeIPA)
 * TFTP - any UNIX based tftp server
 * Facts - module to gather facts from facter (used only on discovered nodes)
 * HTTPBoot - endpoint exposing a (TFTP) directory via HTTP(s) for UEFI HTTP booting
 * Logs - log buffer of proxy logs for easier troubleshooting
 * Templates - unattended Foreman endpoint proxy

# Installation
Read the [Smart Proxy Installation section](https://theforeman.org/manuals/latest/index.html#4.3.1SmartProxyInstallation) of the manual.

# Configuration
Read the [Smart Proxy Settings section](https://theforeman.org/manuals/latest/index.html#4.3.2SmartProxySettings) of the manual.

# For Developers
* [API Reference](https://projects.theforeman.org/projects/smart-proxy/wiki/API)
* Smart Proxy Plugin development [how-to] (https://projects.theforeman.org/projects/foreman/wiki/How_to_Create_a_Smart-Proxy_Plugin)

# Special thanks
The original author of this project is [Ohad Levy](https://github.com/ohadlevy). You can find a more thorough list of people who have contributed to this project at some point in [Contributors](Contributors).

# License
See [LICENSE](LICENSE) file.
