[![Build Status](http://ci.theforeman.org/buildStatus/icon?job=test_proxy_develop)](http://ci.theforeman.org/job/test_proxy_develop/)
[![Code Climate](https://codeclimate.com/github/theforeman/smart-proxy/badges/gpa.svg)](https://codeclimate.com/github/theforeman/smart-proxy)
[![Issue Stats](http://issuestats.com/github/theforeman/smart-proxy/badge/pr)](http://issuestats.com/github/theforeman/smart-proxy)
[![Support IRC channel](https://kiwiirc.com/buttons/irc.freenode.net/theforeman.png)](https://kiwiirc.com/client/irc.freenode.net/?#theforeman)

[Smart Proxy](http://projects.theforeman.org/projects/smart-proxy/wiki) is a free open source project that provides restful API to subsystems such as DNS, DHCP, etc, for higher level orchestration tools such as [Foreman](https://github.com/theforeman/foreman). 

* Issues: [Redmine](http://projects.theforeman.org/projects/smart-proxy/issues)
* Wiki: [Foreman wiki](http://projects.theforeman.org/projects/smart-proxy/wiki)
* Community and support: We use [Freenode](irc.freenode.net) IRC channels
    * #theforeman for general support
    * #theforeman-dev for development chat
* Mailing lists:
    * [foreman-users](https://groups.google.com/forum/?fromgroups#!forum/foreman-users)
    * [foreman-dev](https://groups.google.com/forum/?fromgroups#!forum/foreman-dev)

# Supported Modules
Currently Supported modules:
 * BMC - BMC management of devices supported by freeipmi and ipmitool
 * DHCP - ISC DHCP and MS DHCP Servers
 * DNS - Bind and MS DNS Servers
 * Puppet - Any Puppet server from 0.24.x
 * Puppet CA - Manage certificate signing, cleaning and autosign on a Puppet CA server
 * Realm - Manage host registration to a realm (e.g. FreeIPA)
 * TFTP - any UNIX based tftp server

# Installation
Read the [Smart Proxy Installation section](http://theforeman.org/manuals/latest/index.html#4.3.1SmartProxyInstallation) of the manual.

# Configuration
Read the [Smart Proxy Settings section](http://theforeman.org/manuals/latest/index.html#4.3.2SmartProxySettings) of the manual.

# For Developers
* [API Reference](http://projects.theforeman.org/projects/smart-proxy/wiki/API)
* Smart Proxy Plugin development [how-to] (http://projects.theforeman.org/projects/foreman/wiki/How_to_Create_a_Smart-Proxy_Plugin)

# Special thanks
The original author of this project is [Ohad Levy](http://github.com/ohadlevy). You can find a more thorough list of people who have contributed to this project at some point in [Contributors](Contributors).

# License
See [LICENSE](LICENSE) file.