#!/bin/bash

set -e

if [ $# -lt 1 ]; then
  CONF="/home/build/.nightly-foreman"
else
  CONF="/home/build/.nightly-${1}"
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
/usr/bin/dpkg-buildpackage -F -tc -uc -us

/usr/bin/reprepro -b "${REPO_DIR}" includedsc "${DEB_REPO}" "${BUILD_DIR}"/*.dsc
/usr/bin/reprepro -b "${REPO_DIR}" includedeb "${DEB_REPO}" "${BUILD_DIR}"/*.deb
