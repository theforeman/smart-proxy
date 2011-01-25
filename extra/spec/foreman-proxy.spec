%global homedir %{_datadir}/%{name}
%global confdir config
%global specdir extra/spec

Name:           foreman-proxy
Version:        0.1.0
Release:        1
Summary:        Restful Proxy for DNS, DHCP, TFTP, PuppetCA and Puppet

Group:          Applications/System
License:        GPLv3+
URL:            http://theforeman.org/projects/smart-proxy
Source0:        http://theforeman.org/files/todo/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:      noarch

Requires:       ruby(abi) = 1.8
Requires:       rubygems
Requires:       rubygem(rake) >= 0.8.3
Requires:       rubygem(sinatra)
Requires:       rubygem(json)
Requires(pre):  shadow-utils
Requires(post): chkconfig
Requires(preun): chkconfig
Requires(preun): initscripts
Requires(postun): initscripts

Packager:       Lukas Zapletal <lzap+git@redhat.com>

%description
Manages DNS, DHCP, TFTP and puppet settinsg though HTTP Restful API
Mainly used by the foreman project (http://theforeman.org)

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
install -d -m0755 %{buildroot}%{_datadir}/%{name}
install -d -m0755 %{buildroot}%{_datadir}/%{name}/config
install -d -m0755 %{buildroot}%{_sysconfdir}/%{name}
install -d -m0755 %{buildroot}%{_localstatedir}/lib/%{name}
install -d -m0750 %{buildroot}%{_localstatedir}/log/%{name}

install -Dp -m0644 %{specdir}/%{name}.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/%{name}
install -Dp -m0755 %{specdir}/%{name}.init %{buildroot}%{_initrddir}/%{name}
install -Dp -m0644 %{specdir}/%{name}.logrotate %{buildroot}%{_sysconfdir}/logrotate.d/%{name}
cp -p -r bin lib Rakefile %{buildroot}%{_datadir}/%{name}
chmod a+x %{buildroot}%{_datadir}/%{name}/bin/smart-proxy
rm -rf %{buildroot}%{_datadir}/%{name}/*.rb

# remove all test units from productive release
find %{buildroot}%{_datadir}/%{name} -type d -name "test" |xargs rm -rf

# Move config files to %{_sysconfdir}
install -Dp -m0644 %{confdir}/settings.yml.example %{buildroot}%{_sysconfdir}/%{name}/settings.yml
ln -sv %{_sysconfdir}/%{name}/settings.yml %{buildroot}%{_datadir}/%{name}/config/settings.yml

# Put HTML %{_localstatedir}/lib/%{name}/public
for x in public views; do
  cp -pr $x %{buildroot}%{_localstatedir}/lib/%{name}/
  ln -sv %{_localstatedir}/lib/%{name}/$x %{buildroot}%{_datadir}/%{name}/$x
done

# Put logs in %{_localstatedir}/log/%{name}
ln -sv %{_localstatedir}/log/%{name} %{buildroot}%{_datadir}/%{name}/logs

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,0755)
%doc README
%{_datadir}/%{name}
%{_initrddir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/sysconfig/%{name}
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/lib/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/log/%{name}

%pre
# Add the "foreman-proxy" user and group
getent group foreman-proxy >/dev/null || \
  groupadd -r foreman-proxy
getent passwd foreman-proxy >/dev/null || \
  useradd -r -g foreman-proxy -d %{homedir} -s /sbin/nologin -c "Foreman Proxy deamon user" foreman-proxy
exit 0

%post
/sbin/chkconfig --add %{name}
exit 0

%preun
if [ $1 -eq 0 ] ; then
  /sbin/service %{name} stop >/dev/null 2>&1
  /sbin/chkconfig --del %{name}
fi

%postun
if [ $1 -ge 1 ] ; then
  /sbin/service %{name} restart >/dev/null 2>&1
fi

%changelog
* Wed Jan 26 2011 Lukas Zapletal <lzap+git@redhat.com> - 0.1.0
- new package built with tito
