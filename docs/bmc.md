# Testing BMC

## Redfish

### Redfish Mockup Server

* [Github](https://github.com/DMTF/Redfish-Mockup-Server)
* [Sample mockups](https://www.dmtf.org/dsp/DSP2043)

### Sushy tools

* [Web](https://docs.openstack.org/sushy-tools/latest/)

This is a set of simple simulation tools aimed at supporting the development and testing of the Redfish protocol implementations and, in particular, the [Sushy library](https://docs.openstack.org/sushy/).

## IPMI

### VirtualBMC

* [Github](https://github.com/openstack/virtualbmc)
* Fedora: `python3-virtualbmc`

A virtual BMC for controlling virtual machines using IPMI commands.

The virtual BMC consists of two parts:
* `vbmcd` the daemon that exposes virtual BMCs
* `vbmc` the client that can be used to configure the daemon

The `vbmcd` daemon needs to run as a user that has access to the libvirt instance.
If you're using `qemu:///session` for libvirt, you can run `vbmcd --foreground` as your user.
If you're using `qemu:///system` for libvirt, you can use the `vbmcd.service` provided by the Fedora package.

Once `vmbcd` is running, you can add virtual BMCs using the `vbmc` client:
```
$ vbmc add --libvirt-uri qemu:///session libvirt_domain_name
```
or
```
$ vbmc add --libvirt-uri qemu:///system libvirt_domain_name
```

The username and password of the BMC can be changed using `--username` and `--password`.
The port can't be changed with `--port` as Foreman doesn't allow configuring any other port than `623/udp`

You might need to allow `623/udp` in your firewall: `sudo firewall-cmd --zone=libvirt --add-port=623/udp`.

If you're running `vbmcd` as an unprivileged user, you'll need to allow it to bind to 623: `sudo sysctl net.ipv4.ip_unprivileged_port_start=0`.

Once everything is configured, you can start the virtual BMC with `vbmc start libvirt_domain_name` and Foreman should be able to control the machine using IPMI.
