#!/bin/bash

set -e

if [ $# -lt 1 ]; then
  CONF="/home/greg/build-area/.nightly-foreman"
else
  CONF="/home/greg/build-area/.nightly-${1}"
fi

if [ -f "${CONF}" ]; then
  source "${CONF}"
else
  echo "Couldn't find ${CONF}. Quitting."
  exit 1
fi

DATE=$(date -R)
UNIXTIME=$(date +%s)
RELEASE="${VERSION}-~nightlybuild${UNIXTIME}"

GIT='/usr/bin/git'

mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR}"/*
cd "${BUILD_DIR}"

$GIT clone "${REPO}" "${TARGET}"
cd "${TARGET}"
$GIT checkout "${BRANCH}"
$GIT submodule init
$GIT submodule update

LAST_COMMIT=$($GIT rev-list HEAD|/usr/bin/head -n 1)

prepare_build

rm -rf $(/usr/bin/find "${TARGET}" -name '.git*')

mv debian/changelog debian/changelog.tmp

echo "$PACKAGE_NAME ($RELEASE) UNRELEASED; urgency=low

  * Automatically built package based on the state of
    $REPO at commit $LAST_COMMIT

 -- $MAINTAINER  $DATE
" > debian/changelog

cat debian/changelog.tmp >> debian/changelog
rm -f debian/changelog.tmp

echo -n '3.0 (native)' > debian/source/format
# We use -d here since on a Centos box we can't check the installed debs
/usr/bin/dpkg-buildpackage -d -tc -uc -us

#/home/greg/bin/reprepro -b "${REPO_DIR}" includedeb "${DEB_REPO}" "${BUILD_DIR}"/*.deb
/home/greg/bin/reprepro --ignore=wrongdistribution -b "${REPO_DIR}" include "${DEB_REPO}" "${BUILD_DIR}"/*.changes
