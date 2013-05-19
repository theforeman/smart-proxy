%global homedir %{_datadir}/%{name}
%global confdir config
%global specdir extra/spec
%global scl ruby193

%if "%{?scl}" == "ruby193"
    %global scl_prefix %{scl}-
    %global scl_ruby /usr/bin/ruby193-ruby
%else
    %global scl_ruby /usr/bin/ruby
%endif


Name:           foreman-proxy
Version:        1.1.9999
Release:        1%{dist}
Summary:        Restful Proxy for DNS, DHCP, TFTP, PuppetCA and Puppet

Group:          Applications/System
License:        GPLv3+
URL:            http://theforeman.org/projects/smart-proxy
Source0:        http://theforeman.org/files/todo/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:      noarch

%if 0%{?fedora} && 0%{?fedora} < 17
Requires: %{?scl_prefix}ruby(abi) = 1.8
%else
%if 0%{?fedora} && 0%{?fedora} > 18
Requires: %{?scl_prefix}ruby(release)
%else
Requires: %{?scl_prefix}ruby(abi) = 1.9.1
%endif
%endif

#%if 0%{?rhel} == 6 || 0%{?fedora} < 17
#Requires: ruby(abi) = 1.8
#%else
#Requires: ruby(abi) = 1.9.1
#%endif


Requires:       %{?scl_prefix}rubygems
Requires:       %{?scl_prefix}rubygem(rake) >= 0.8.3
Requires:       %{?scl_prefix}rubygem(sinatra)
Requires:       %{?scl_prefix}rubygem(json)
Requires:       sudo
Requires:       wget
%if 0%{?rhel} == 6 || 0%{?fedora} < 17
Requires(pre):  shadow-utils
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

# Link temp directory to system wide temp
ln -sv %{_tmppath} %{buildroot}%{_datadir}/%{name}/tmp

%clean
rm -rf %{buildroot}

%files
%doc README
%{_datadir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/logrotate.d/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/lib/%{name}
%attr(-,%{name},%{name}) %{_localstatedir}/log/%{name}
%attr(-,%{name},%{name}) %{_var}/run/%{name}
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
* Thu May 16 2013 Martin Bačovský <mbacovsk@redhat.com> 1.2-1
- added support for building with tito

* Fri Apr 05 2013 Miroslav Suchý <msuchy@redhat.com> 1.0.1-11.aff8fa8
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- remove Fedora 17 releasers (msuchy@redhat.com)
- fixes #2067 - disable puppet's handling of 'import' to fix manifests
  containing it (dcleal@redhat.com)
- Ignore .bundle dir (dcleal@redhat.com)
- fixes #2209 - explicitly use Proxy::Puppet::Environment#name for to_json
  (dcleal@redhat.com)
- fixes #2255 Fix frozen facts in facts_api (gsutclif@redhat.com)
- fixes #2191 - undef in puppet class params is optional (dcleal@redhat.com)
- Fixed bad indentation in the puppet clasS (shk@redhat.com)
- fixes #2261 - fixes for CI testing under Ruby 1.9 (dcleal@redhat.com)
- ignore RVM/RBenv files (gsutclif@redhat.com)
- Fixed CVE-2013-0210 and added test for new escape method (shk@redhat.com)

* Tue Feb 19 2013 Miroslav Suchý <msuchy@redhat.com> 1.0.1-10.fe7d7e9
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- Adding sudo and wget deps, for puppetca and tftp features (msuchy@redhat.com)
- released 1.1 (ohadlevy@gmail.com)
- Tests the autosign.conf operations (jan@vstone.eu)
- fixes #1674: Ignore commented lines when reading all certificates in autosign
  and make sure the autosign file contains a EOL on the last line
  (jan@vstone.eu)
- Fix a number of tests and settings so tests run from example settings.yml
  (dcleal@redhat.com)
- fixes #2101 - add bundler / Gemfile (dcleal@redhat.com)
- version bump to RC3 (ohadlevy@gmail.com)
- refs #1567 - fixed a copy paste error (ohadlevy@gmail.com)
- Fixes #2143: Only create the log file parent dir if daemonize is true
  (shk@linux.com)
- fixes #2085 - load Puppet 3 app defaults for master mode too
  (dcleal@redhat.com)
- fixes #2114 Add warning if no environments found (christoph@web.crofting.com)
- fixes #2099 - interpolate $confdir if $environment not used
  (dcleal@redhat.com)
- fixes #2099 - fix handling of multiple module paths (raffael@yux.ch)

* Thu Jan 03 2013 Miroslav Suchý <msuchy@redhat.com> 1.0.1-9.4c3b483
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- merge https://github.com/theforeman/foreman-rpms/pull/29 (msuchy@redhat.com)
- fixes #2077 - proxy should not return nil for parameters with a function call
  (ohadlevy@gmail.com)
- fix tests running on both 1.8 and 1.9 ruby (gsutclif@redhat.com)
- release bump to 1.1RC1 (ohadlevy@gmail.com)
- fixes #2031 - Remove dependency on net-ping (gsutclif@redhat.com)
- fixes #2016 Use a tmpfile+lockfile to avoid race conditions in IP suggestion
  (gsutclif@redhat.com)
- fixes #1983 - use /etc/puppet/puppet.conf by default (dcleal@redhat.com)
- Fixes #1984 - explicitly call array.join when writing autosign.conf
  (gsutclif@redhat.com)
- fixes #1967 - missing require for Puppet constant (dcleal@redhat.com)
- fixes #1915 - load environments from Puppet 3 (dcleal@redhat.com)

* Mon Dec 03 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-8.a865cba
- do just condrestart after logrotate (msuchy@redhat.com)
- do not call directly service script, but use service command
  (msuchy@redhat.com)
- convert to systemd (msuchy@redhat.com)
- add back packaging files (msuchy@redhat.com)

* Fri Nov 16 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-7.a865cba
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- Fixes #1941 - Load only the puppet binary when puppet 3 or higher is used
  (shk@redhat.com)
- Removed files related to packaging (shk@redhat.com)
- More detailed log message for puppetca ssldir Add ssldir and puppetdir to
  config examples Fixes #1104 (gsutclif@redhat.com)

* Mon Nov 12 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-6.c8ee1bf
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- Fixes #1761 - default to /etc/puppet if we can't find a value for
  (gsutclif@redhat.com)

* Thu Nov 08 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-5.6093c50
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- fixes #1929 - set umask sensibly to prevent world writable files
  (CVE-2012-5477) (dcleal@redhat.com)

* Thu Oct 25 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-4.6c45874
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- Fixes #1914: Raise if we cannot read the puppet conf file, report the path
  otherwise (gsutclif@redhat.com)

* Fri Sep 14 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-3.200ce90
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- fixes #1856 - adds a config.ru and allow the SP to run as a rack app.
  (ohadlevy@gmail.com)

* Thu Sep 13 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.1-2.07aedac
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)

* Wed Sep 05 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-7.a402c71
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' by rel-eng/build.sh
  (msuchy@redhat.com)
- merge automatically (msuchy@redhat.com)
- fixes #1836 - puppet cert in 2.7.19 has a different exit code
  (ohadlevy@gmail.com)

* Wed Aug 29 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-6.330dbef
- Automatic rebase to latest nightly Foreman-proxy (msuchy@redhat.com)
- Merge remote-tracking branch 'smartproxy/develop' (msuchy@redhat.com)
- fixes #1835 - proxy now can import classes from puppet 2.7.19
  (ohadlevy@gmail.com)
- Create the pid parent dir if it doesn't exist (sam@kottlerdevelopment.com)
- feature #1829 - add bmc ipmi support to smart proxy (corey@logicminds.biz)
- script building nightly (msuchy@redhat.com)

* Thu Aug 09 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-5.1418075
- allow to build foreman-proxy for both ruby 1.8 and 1.9.1 (msuchy@redhat.com)

* Thu Aug 09 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-4.1418075
- show from which git hash we build it (msuchy@redhat.com)

* Thu Aug 09 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-3
- top dir of tar.gz is name-version (msuchy@redhat.com)
- tito use tar.gz (msuchy@redhat.com)

* Thu Aug 09 2012 Miroslav Suchý <msuchy@redhat.com> 1.0.0-2
- rebuild

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
