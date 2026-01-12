#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing,
#   software distributed under the License is distributed on an
#   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#   KIND, either express or implied.  See the License for the
#   specific language governing permissions and limitations
#   under the License.

# This shell script installs all OS package dependencies for Apache
# CouchDB 2.x for yum-based systems.
#
# While these scripts are primarily written to support building CI
# Docker images, they can be used on any workstation to install a
# suitable build environment.

# stop on error
set -e

fake-rpm() {
  tmpdir=/tmp/$1rpm
  mkdir -p $tmpdir/rpmbuild/{SOURCES,BUILD,RPMS}/noarch
  cat > $tmpdir/rpmbuild/SOURCES/README <<EOF
Fake package to appease later package builders.
EOF
  cat > $tmpdir/fake$1.spec <<EOF
Name:        fake-$1
Version:     $2
Release:     1%{?dist}
Summary:     Fake package for $1
Group:       Fake
License:     BSD
BuildRoot:   %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Source:      README
Provides:    $1
BuildArch:   noarch

%description
%{summary}

%prep
%setup -c -T

%build
cp %{SOURCE0} .

%install

%files
%defattr(-,root,root,-)
%doc README

%changelog

EOF
  rpmbuild --verbose -bb --define "_topdir $tmpdir/rpmbuild" $tmpdir/fake$1.spec
  yum --nogpgcheck localinstall -y $tmpdir/rpmbuild/RPMS/*/*.rpm
  rm -rf $tmpdir
}


# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  echo "Sorry, this script must be run as root."
  echo "Try: sudo $0 $*"
  exit 1
fi

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${SCRIPTPATH}/detect-os.sh >/dev/null
. ${SCRIPTPATH}/detect-arch.sh >/dev/null
echo "Detected RedHat/Centos/Fedora version: ${VERSION_ID}   arch: ${ARCH}"

# TODO: Do the Right Things(tm) for Fedora

dnf update -y

# Enable EPEL
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VERSION_ID}.noarch.rpm || true
# PowerTools for Alma 8 and python 3.12
if [[ ${VERSION_ID} -eq 8 ]]; then
  dnf install -y 'dnf-command(config-manager)'
  dnf config-manager --set-enabled powertools
  dnf update -y
fi
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY*
# more for RHEL than CentOS...
dnf install subscription-manager -y
subscription-manager repos \
  --enable "rhel-*-optional-rpms" \
  --enable "rhel-*-extras-rpms" \
 >/dev/null 2>&1 || true

# Upgrade all packages
dnf upgrade -y

# Install auxiliary packages
dnf groupinstall -y 'Development Tools'

# Dependencies for make couch, except erlang and package building stuff.
# help2man is for docs
dnf install -y sudo git wget which autoconf autoconf-archive automake curl-devel libicu-devel \
    libtool ncurses-devel nspr-devel zip readline-devel unzip perl \
    createrepo xfsprogs-devel java-21-openjdk-devel rpmdevtools time
if [[ ${VERSION_ID} -eq 9 ]]; then
  dnf --enablerepo=crb install -y help2man
elif [[ ${VERSION_ID} -eq 8 ]]; then
  dnf install -y help2man
fi

dnf install -y python3.12 python3.12-pip python3.12-wheel
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 99
alternatives --set python3 /usr/bin/python3.12
alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.12 99
alternatives --set pip3 /usr/bin/pip3.12

# Node.js
pushd /tmp
wget https://rpm.nodesource.com/setup_${NODEVERSION}.x
set +e
/bin/bash setup_${NODEVERSION}.x
if [ $? -ne 0 ]; then
  set -e
  # extracting the right version to dl is a pain :(
  SAVEARCH=${ARCH}
  if [ ${SAVEARCH} == "x86_64" ]; then SAVEARCH=x64; fi
  node_filename="$(curl -s https://nodejs.org/dist/latest-v${NODEVERSION}.x/SHASUMS256.txt | grep linux-${SAVEARCH}.tar.gz | cut -d ' ' -f 3)"
  wget https://nodejs.org/dist/latest-v${NODEVERSION}.x/${node_filename}
  tar --directory=/usr --strip-components=1 -xzf ${node_filename}
  rm ${node_filename}
  # then, fake a package install
  fake-rpm nodejs ${NODEVERSION}.0.0
else
  set -e
  dnf install -y nodejs
fi
rm setup_${NODEVERSION}.x
npm install npm@latest -g
popd


# js packages, as long as we're not told to skip them
if [[ $1 != "nojs" ]]; then
  if [[ ${VERSION_ID} -eq 8 ]]; then
    dnf install -y mozjs60-devel
  elif [[ ${VERSION_ID} -eq 9 ]]; then
    dnf install -y mozjs78-devel
  fi
  # For 10 and up skip install mozjs, we'll use quickjs instead
else
  # install js build-time dependencies only
  # we can't add the CouchDB repo here because the plat may not exist yet
  dnf install -y libffi-devel
fi

# remove openjdk8 and jna, java 21 is installed and should be the default
# and clouseau installs it's own JRE 8 in /opt via a docker layer
dnf remove -y java-1.8.0-openjdk-headless jna

# clean up
dnf clean all -y
