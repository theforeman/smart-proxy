%global homedir %{_datadir}/%{name}
%global confdir config
%global specdir extra/spec

%if "%{?scl}" == "ruby193"
    %global scl_prefix %{scl}-
    %global scl_ruby /usr/bin/ruby193-ruby
%else
    %global scl_ruby /usr/bin/ruby
%endif

Name:           foreman-proxy
Version:        1.4.0
Release:        0.1.RC1%{dist}
Summary:        Restful Proxy for DNS, DHCP, TFTP, PuppetCA and Puppet

Group:          Applications/System
License:        GPLv3+
URL:            http://theforeman.org/projects/smart-proxy
Source0:        http://theforeman.org/files/todo/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:      noarch

%if "%{?scl}" == "ruby193" || 0%{?rhel} > 6 || (0%{?fedora} > 16 && 0%{?fedora} < 19)
Requires: %{?scl_prefix}ruby(abi) = 1.9.1
%else
%if 0%{?fedora} && 0%{?fedora} > 18
Requires: %{?scl_prefix}ruby(release)
%else
Requires: %{?scl_prefix}ruby(abi) = 1.8
%endif
%endif

Requires:       %{?scl_prefix}rubygems
Requires:       %{?scl_prefix}rubygem(rake) >= 0.8.3
Requires:       %{?scl_prefix}rubygem(sinatra)
Requires:       %{?scl_prefix}rubygem(json)
Requires:       %{?scl_prefix}rubygem(rkerberos)
Requires:       %{?scl_prefix}rubygem(rubyipmi)
Requires:       sudo
Requires:       wget
Requires(pre):  shadow-utils
%if 0%{?rhel} == 6 || 0%{?fedora} < 17
Requires(post): chkconfig
Requires(preun): chkconfig
Requires(preun): initscripts
Requires(postun): initscripts
%else
Requires(post): systemd-sysv
Requires(post): systemd-units
Requires(preun): systemd-units
Requires(postun): systemd-units
BuildRequires: systemd-units
%endif


%description
Manages DNS, DHCP, TFTP and puppet settings though HTTP Restful API
Mainly used by the foreman project (http://theforeman.org)

%prep
%setup -q

%build

#replace shebangs for SCL
%if %{?scl:1}%{!?scl:0}
  for f in bin/smart-proxy extra/query.rb extra/changelog; do
    sed -ri '1sX(/usr/bin/ruby|/usr/bin/env ruby)X%{scl_ruby}X' $f
  done
  sed -ri '1,$sX/usr/bin/rubyX%{scl_ruby}X' extra/spec/foreman-proxy.init
%endif


%install
rm -rf %{buildroot}
install -d -m0755 %{buildroot}%{_datadir}/%{name}
install -d -m0755 %{buildroot}%{_datadir}/%{name}/config
install -d -m0755 %{buildroot}%{_sysconfdir}/%{name}
install -d -m0755 %{buildroot}%{_localstatedir}/lib/%{name}
install -d -m0750 %{buildroot}%{_localstatedir}/log/%{name}
install -d -m0750 %{buildroot}%{_var}/run/%{name}

%if 0%{?rhel} == 6 || 0%{?fedora} < 17
install -Dp -m0644 %{specdir}/%{name}.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/%{name}
install -Dp -m0755 %{specdir}/%{name}.init %{buildroot}%{_initrddir}/%{name}
install -Dp -m0644 %{specdir}/logrotate %{buildroot}%{_sysconfdir}/logrotate.d/%{name}
%else
install -Dp -m0644 %{specdir}/%{name}.service %{buildroot}%{_unitdir}/%{name}.service
install -Dp -m0644 %{specdir}/%{name}.tmpfiles %{buildroot}%{_prefix}/lib/tmpfiles.d/%{name}.conf
install -Dp -m0644 %{specdir}/logrotate.systemd %{buildroot}%{_sysconfdir}/logrotate.d/%{name}
%endif

cp -p -r bin lib Rakefile config.ru %{buildroot}%{_datadir}/%{name}
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

# Link temp directory to system wide temp
ln -sv %{_tmppath} %{buildroot}%{_datadir}/%{name}/tmp

%clean
rm -rf %{buildroot}

%files
%doc README LICENSE
%{_datadir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/lib/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/log/%{name}
%attr(-,%{name},%{name}) %{_var}/run/%{name}
%attr(-,%{name},root) %{_datadir}/%{name}/config.ru
%if 0%{?rhel} == 6 || 0%{?fedora} < 17
%{_initrddir}/%{name}
%config(noreplace) %{_sysconfdir}/sysconfig/%{name}
%else
%{_unitdir}/%{name}.service
%{_prefix}/lib/tmpfiles.d/%{name}.conf
%endif

%pre
# Add the "foreman-proxy" user and group
getent group foreman-proxy >/dev/null || \
  groupadd -r foreman-proxy
getent passwd foreman-proxy >/dev/null || \
  useradd -r -g foreman-proxy -d %{homedir} -s /sbin/nologin -c "Foreman Proxy deamon user" foreman-proxy
exit 0

%post
%if 0%{?rhel} == 6 || 0%{?fedora} < 17
  /sbin/chkconfig --add %{name}
  exit 0
%else
  if [ $1 -eq 1 ]; then
    /bin/systemctl daemon-reload >/dev/null 2>&1 || :
  fi
%endif

%preun
if [ $1 -eq 0 ] ; then
  # Package removal, not upgrade
  %if 0%{?rhel} == 6 || 0%{?fedora} < 17
    /sbin/service %{name} stop >/dev/null 2>&1
    /sbin/chkconfig --del %{name}
  %else
    /bin/systemctl --no-reload disable foreman-proxy.service >/dev/null 2>&1 || :
    /bin/systemctl stop foreman-proxy.service >/dev/null 2>&1 || :
  %endif
fi

%postun
%if 0%{?rhel} == 6 || 0%{?fedora} < 17
  if [ $1 -ge 1 ] ; then
    /sbin/service %{name} restart >/dev/null 2>&1
  fi
%else
  /bin/systemctl daemon-reload >/dev/null 2>&1 || :
  if [ $1 -ge 1 ] ; then
    /bin/systemctl try-restart foreman-proxy.service >/dev/null 2>&1 || :
  fi
%endif


%changelog
* Thu Jan 16 2014 Dominic Cleal <dcleal@redhat.com> - 1.4.0-0.1.RC1
- Release 1.4.0-RC1
- Bump and change versioning scheme (#3712)
- Ship config.ru for running under Passenger

* Thu Sep 05 2013 Lukas Zapletal <lzap+rpm[@]redhat.com> - 1.3.9999-1
- bump to version 1.3-develop
* Wed Jul 03 2013 Dominic Cleal <dcleal@redhat.com> - 1.2.9999-3
- add rubyipmi dependency for BMC support
* Wed Jun 13 2013 Lukas Zapletal <lzap+rpm[@]redhat.com> - 1.2.9999-2
- fixed service file for systemd
- /etc/sysconfig configuration is no longer in use for systemd
* Thu May 16 2013 Martin Bačovský <mbacovsk@redhat.com> 1.2.9999-1
- added support for building with tito
* Mon Feb 4 2013 shk@redhat.com 1.1-1
- 1.1 final.
* Fri Jan 25 2013 shk@redhat.com 1.1RC3-1
- Updated to RC3
* Wed Jan 09 2013 shk@redhat.com 1.1RC2-1
- Updated to RC2
- Removed net-ping dependency
* Tue Jan 1 2013 shk@redhat.com 1.1RC1-1
- Update to 1.1RC1
* Thu Aug 30 2012 jmontleo@redhat.com 1.0.0-3
- Update to include up to 330dbef353
* Sun Aug 05 2012 jmontleo@redhat.com 1.0.0-2
- Update to pull in fixes
* Mon Jul 23 2012 jmontleo@redhat.com 1.0.0-1
- Update packages for Foreman 1.0 Release.
* Wed Jul 18 2012 jmontleo@redhat.com 1.0.0-0.7
- Updated pacakages for Foreman 1.0 RC5 and Proxy RC2
* Thu Jul 05 2012 jmontleo@redhat.com 1.0.0-0.6
- Fix foreman-release to account for different archs. Pull todays source.
* Wed Jul 04 2012 jmontleo@redhat.com 1.0.0-0.5
- Bump version number for foreman RC3 and build with todays develop branch
* Sun Jul 01 2012 jmontleo@redhat.com 1.0.0-0.4
- Pull todays develop branch
* Fri Jun 29 2012 jmontleo@redhat.com 1.0.0-0.2
- Rebuild with develop branch from today. Hopefully we're really 1.0.0 RC2 this time
* Tue Jun 19 2012 jmontleo@redhat.com 0.5.1-9
- Rebuild with todays develop branch.
* Thu Jun 14 2012 jmontleo@redhat.com 0.5.1-8
- Rebuild with todays develop branch.
* Tue May 08 2012 Jason Montleon <jmontleo@redhat.com> - 0.5.1-1
- update version to match foreman package version
* Wed Dec 28 2011 Ohad Levy <ohadlevy@gmail.com> - 0.3.1
- rebuilt
* Wed Nov 08 2011 Ohad Levy <ohadlevy@gmail.com> - 0.3
- rebuilt
* Wed Sep 28 2011 Ohad Levy <ohadlevy@gmail.com> - 0.3rc2
- rebuilt
* Sat Sep 10 2011 Ohad Levy <ohadlevy@gmail.com> - 0.3rc1
- rebuilt
* Mon Jun 6 2011 Ohad Levy <ohadlevy@gmail.com> - 0.2
- rebuilt
* Thu May 26 2011 ohadlevy@gmail.com - 0.2rc2-2
- rebuilt
* Thu Feb 24 2011 Ohad Levy <ohadlevy@gmail.com> - 0.1.0rc
- new package built with tito
* Wed Jan 26 2011 Lukas Zapletal <lzap+git@redhat.com> - 0.1.0
- new package built with tito
